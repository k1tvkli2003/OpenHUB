from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

_MARKER_NAME = ".openhub-native-test-fixture.json"
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_MAX_MARKER_BYTES = 64 * 1024


class NativeFixtureValidationError(RuntimeError):
    pass


def validate_native_fixture_data_dir(data_dir: Path, *, home: Path | None = None) -> None:
    resolved = data_dir.expanduser().resolve()
    live = ((home or Path.home()).expanduser().resolve() / ".openhub").resolve()
    resolved_hash = _path_hash(resolved)
    live_hash = _path_hash(live)
    if resolved == live or resolved_hash == live_hash:
        raise NativeFixtureValidationError("Native fixture mode refuses the live openhub data directory.")
    marker_path = resolved / _MARKER_NAME
    try:
        if marker_path.stat().st_size > _MAX_MARKER_BYTES:
            raise NativeFixtureValidationError("Native fixture identity marker exceeds the safety limit.")
        marker = json.loads(marker_path.read_text(encoding="utf-8-sig"))
    except NativeFixtureValidationError:
        raise
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise NativeFixtureValidationError("Native fixture identity marker is missing or invalid.") from exc
    if not isinstance(marker, dict) or marker.get("schema_version") != 1:
        raise NativeFixtureValidationError("Native fixture identity marker has an unsupported schema.")
    fixture_id = marker.get("fixture_id")
    marker_path_text = marker.get("fixture_path")
    marker_path_hash = marker.get("fixture_path_sha256")
    marker_live_hash = marker.get("live_path_sha256")
    files = marker.get("files")
    if (
        not isinstance(fixture_id, str)
        or not fixture_id
        or not isinstance(marker_path_text, str)
        or not isinstance(marker_path_hash, str)
        or not isinstance(marker_live_hash, str)
        or not isinstance(files, dict)
    ):
        raise NativeFixtureValidationError("Native fixture identity marker is incomplete.")
    try:
        marker_resolved = Path(marker_path_text).expanduser().resolve()
    except OSError as exc:
        raise NativeFixtureValidationError("Native fixture recorded path is invalid.") from exc
    if marker_resolved != resolved or marker_path_hash != resolved_hash:
        raise NativeFixtureValidationError("Native fixture path does not match its recorded identity.")
    if marker_live_hash != live_hash or marker_path_hash == live_hash:
        raise NativeFixtureValidationError("Native fixture marker does not match the current live-store identity.")
    for name in ("store.db", "encryption.key"):
        expected = files.get(name)
        target = resolved / name
        if not isinstance(expected, str) or not _SHA256_RE.fullmatch(expected):
            raise NativeFixtureValidationError(f"Native fixture marker is missing the {name} hash.")
        try:
            actual = _file_hash(target)
        except OSError as exc:
            raise NativeFixtureValidationError(f"Native fixture is missing required file: {name}.") from exc
        if actual != expected:
            raise NativeFixtureValidationError(f"Native fixture pre-start hash verification failed for {name}.")


def _path_hash(path: Path) -> str:
    normalized = str(path).casefold().encode("utf-8")
    return hashlib.sha256(normalized).hexdigest()


def _file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()
