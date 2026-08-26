from __future__ import annotations

import json
import os
import re
import tempfile
import threading
from dataclasses import asdict, dataclass
from functools import lru_cache
from pathlib import Path
from urllib.parse import urlsplit

from app.core.config.settings import get_settings

_MAX_STATE_BYTES = 256 * 1024
_MAX_PROFILES = 64
_PROFILE_ID = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$")
_PROVIDER_ID = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$")
_BUILTIN_IDS = frozenset({"openai-pool", "ox"})
_CATALOG_URI_PREFIXES = ("asset://", "profile://")


class CodexProfileError(RuntimeError):
    pass


class CodexProfileConflictError(CodexProfileError):
    pass


@dataclass(frozen=True)
class CodexProfile:
    id: str
    label: str
    kind: str
    model_provider: str
    model: str
    wire_api: str
    base_url: str | None
    catalog_source: str
    catalog_uri: str | None
    bridge_uri: str | None
    context_window: int | None
    account_routing: str
    builtin: bool


@dataclass(frozen=True)
class CodexProfileRegistry:
    state_path: Path
    revision: int
    active_profile_id: str
    profiles: tuple[CodexProfile, ...]


@dataclass(frozen=True)
class CodexProfileMutation:
    registry: CodexProfileRegistry
    changed: bool


class CodexProfileService:
    """Owns portable profile policy without storing provider credentials."""

    def __init__(self, data_root: Path | None = None) -> None:
        self._data_root = (data_root or get_settings().data_dir).expanduser().resolve()
        self._state_path = self._data_root / "openhub-profiles.json"
        self._lock = threading.RLock()

    def snapshot(self) -> CodexProfileRegistry:
        with self._lock:
            return self._read_registry()

    def upsert(
        self,
        *,
        expected_revision: int,
        profile: CodexProfile,
    ) -> CodexProfileMutation:
        validated = _validate_profile(profile, allow_builtin=False)
        with self._lock:
            current = self._read_registry()
            self._require_revision(current, expected_revision)
            if validated.id in _BUILTIN_IDS:
                raise CodexProfileError("Built-in Codex profiles cannot be replaced.")
            profiles = {item.id: item for item in current.profiles}
            changed = profiles.get(validated.id) != validated
            if not changed:
                return CodexProfileMutation(registry=current, changed=False)
            profiles[validated.id] = validated
            if len(profiles) > _MAX_PROFILES:
                raise CodexProfileError("The Codex profile limit has been reached.")
            return self._persist(
                revision=current.revision + 1,
                active_profile_id=current.active_profile_id,
                profiles=tuple(profiles.values()),
            )

    def delete(self, *, expected_revision: int, profile_id: str) -> CodexProfileMutation:
        normalized_id = _normalize_profile_id(profile_id)
        with self._lock:
            current = self._read_registry()
            self._require_revision(current, expected_revision)
            if normalized_id in _BUILTIN_IDS:
                raise CodexProfileError("Built-in Codex profiles cannot be deleted.")
            if normalized_id == current.active_profile_id:
                raise CodexProfileConflictError("The active Codex profile cannot be deleted.")
            profiles = {item.id: item for item in current.profiles}
            if profiles.pop(normalized_id, None) is None:
                raise CodexProfileError("The Codex profile was not found.")
            return self._persist(
                revision=current.revision + 1,
                active_profile_id=current.active_profile_id,
                profiles=tuple(profiles.values()),
            )

    def activate(self, *, expected_revision: int, profile_id: str) -> CodexProfileMutation:
        normalized_id = _normalize_profile_id(profile_id)
        with self._lock:
            current = self._read_registry()
            self._require_revision(current, expected_revision)
            if not any(item.id == normalized_id for item in current.profiles):
                raise CodexProfileError("The Codex profile was not found.")
            if current.active_profile_id == normalized_id:
                return CodexProfileMutation(registry=current, changed=False)
            return self._persist(
                revision=current.revision + 1,
                active_profile_id=normalized_id,
                profiles=current.profiles,
            )

    def _persist(
        self,
        *,
        revision: int,
        active_profile_id: str,
        profiles: tuple[CodexProfile, ...],
    ) -> CodexProfileMutation:
        ordered = _ordered_profiles(profiles)
        payload = {
            "version": 1,
            "revision": revision,
            "active_profile_id": active_profile_id,
            "profiles": [asdict(item) for item in ordered],
        }
        self._atomic_json_write(payload)
        verified = self._read_registry()
        expected = CodexProfileRegistry(
            state_path=self._state_path,
            revision=revision,
            active_profile_id=active_profile_id,
            profiles=ordered,
        )
        if verified != expected:
            raise CodexProfileError("Codex profile state failed post-write verification.")
        return CodexProfileMutation(registry=verified, changed=True)

    def _read_registry(self) -> CodexProfileRegistry:
        if not self._state_path.exists():
            return CodexProfileRegistry(
                state_path=self._state_path,
                revision=0,
                active_profile_id="openai-pool",
                profiles=_default_profiles(),
            )
        if not self._state_path.is_file():
            raise CodexProfileError("Codex profile state path is not a regular file.")
        try:
            if self._state_path.stat().st_size > _MAX_STATE_BYTES:
                raise CodexProfileError("Codex profile state exceeds the safety limit.")
            payload = json.loads(self._state_path.read_text(encoding="utf-8"))
        except CodexProfileError:
            raise
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise CodexProfileError("Codex profile state is invalid.") from exc
        if not isinstance(payload, dict) or payload.get("version") != 1:
            raise CodexProfileError("Codex profile state has an unsupported format.")
        revision = payload.get("revision")
        active_profile_id = payload.get("active_profile_id")
        raw_profiles = payload.get("profiles")
        if (
            not isinstance(revision, int)
            or isinstance(revision, bool)
            or revision < 0
            or not isinstance(active_profile_id, str)
            or not isinstance(raw_profiles, list)
            or len(raw_profiles) > _MAX_PROFILES
        ):
            raise CodexProfileError("Codex profile state is invalid.")
        profiles: list[CodexProfile] = []
        for raw_profile in raw_profiles:
            if not isinstance(raw_profile, dict):
                raise CodexProfileError("Codex profile state contains an invalid profile.")
            try:
                profile = CodexProfile(**raw_profile)
            except TypeError as exc:
                raise CodexProfileError("Codex profile state contains an incomplete profile.") from exc
            profiles.append(_validate_profile(profile, allow_builtin=True))
        by_id = {item.id: item for item in profiles}
        if len(by_id) != len(profiles):
            raise CodexProfileError("Codex profile ids must be unique.")
        for builtin in _default_profiles():
            stored = by_id.get(builtin.id)
            if stored is None:
                by_id[builtin.id] = builtin
            elif stored != builtin:
                raise CodexProfileError("Built-in Codex profile policy is invalid.")
        if active_profile_id not in by_id:
            raise CodexProfileError("The active Codex profile does not exist.")
        return CodexProfileRegistry(
            state_path=self._state_path,
            revision=revision,
            active_profile_id=active_profile_id,
            profiles=_ordered_profiles(tuple(by_id.values())),
        )

    @staticmethod
    def _require_revision(current: CodexProfileRegistry, expected_revision: int) -> None:
        if current.revision != expected_revision:
            raise CodexProfileConflictError(
                "Codex profiles changed after they were loaded; refresh and try again."
            )

    def _atomic_json_write(self, payload: dict[str, object]) -> None:
        self._state_path.parent.mkdir(parents=True, exist_ok=True)
        encoded = (json.dumps(payload, sort_keys=True) + "\n").encode("utf-8")
        fd, temp_name = tempfile.mkstemp(
            prefix=f".{self._state_path.name}.",
            suffix=".tmp",
            dir=self._state_path.parent,
        )
        temp_path = Path(temp_name)
        try:
            with os.fdopen(fd, "wb") as handle:
                handle.write(encoded)
                handle.flush()
                os.fsync(handle.fileno())
            _harden(temp_path)
            os.replace(temp_path, self._state_path)
            _harden(self._state_path)
        finally:
            if temp_path.exists():
                temp_path.unlink()


def _default_profiles() -> tuple[CodexProfile, CodexProfile]:
    return (
        CodexProfile(
            id="openai-pool",
            label="OpenAI Pool",
            kind="openai_pool",
            model_provider="openai",
            model="gpt-5.6-sol",
            wire_api="responses",
            base_url=None,
            catalog_source="live_managed",
            catalog_uri=None,
            bridge_uri=None,
            context_window=None,
            account_routing="automatic",
            builtin=True,
        ),
        CodexProfile(
            id="ox",
            label="Ox",
            kind="ox",
            model_provider="opencode_zen",
            model="x-preview-f-free",
            wire_api="responses",
            base_url="http://127.0.0.1:17891/v1",
            catalog_source="bundled",
            catalog_uri="asset://ox/opencode-ox.json",
            bridge_uri="asset://ox/openhub-ox-adapter.mjs",
            context_window=1_000_000,
            account_routing="none",
            builtin=True,
        ),
    )


def _validate_profile(profile: CodexProfile, *, allow_builtin: bool) -> CodexProfile:
    profile_id = _normalize_profile_id(profile.id)
    label = profile.label.strip()
    if not label or len(label) > 80 or any(ord(char) < 32 for char in label):
        raise CodexProfileError("Codex profile label is invalid.")
    if profile.kind not in {"openai_pool", "ox", "custom"}:
        raise CodexProfileError("Codex profile kind is invalid.")
    if not _PROVIDER_ID.fullmatch(profile.model_provider):
        raise CodexProfileError("Codex model provider id is invalid.")
    model = profile.model.strip()
    if not model or len(model) > 256 or any(char.isspace() for char in model):
        raise CodexProfileError("Codex profile model is invalid.")
    if profile.wire_api not in {"responses", "chat_completions"}:
        raise CodexProfileError("Codex profile wire API is invalid.")
    if profile.catalog_source not in {"live_managed", "bundled", "none"}:
        raise CodexProfileError("Codex profile catalog source is invalid.")
    if profile.account_routing not in {"automatic", "manual", "none"}:
        raise CodexProfileError("Codex profile account routing is invalid.")
    if profile.base_url is not None:
        _validate_base_url(profile.base_url)
    for uri in (profile.catalog_uri, profile.bridge_uri):
        if uri is not None and (
            len(uri) > 512 or not uri.startswith(_CATALOG_URI_PREFIXES) or ".." in uri.split("/")
        ):
            raise CodexProfileError("Codex profile asset URI is invalid.")
    if profile.context_window is not None and (
        not isinstance(profile.context_window, int)
        or isinstance(profile.context_window, bool)
        or profile.context_window < 4096
        or profile.context_window > 4_000_000
    ):
        raise CodexProfileError("Codex profile context window is invalid.")
    if profile.builtin and (not allow_builtin or profile_id not in _BUILTIN_IDS):
        raise CodexProfileError("Custom Codex profiles cannot claim built-in status.")
    if not profile.builtin and profile_id in _BUILTIN_IDS:
        raise CodexProfileError("Built-in Codex profile ids are reserved.")
    return CodexProfile(
        id=profile_id,
        label=label,
        kind=profile.kind,
        model_provider=profile.model_provider,
        model=model,
        wire_api=profile.wire_api,
        base_url=profile.base_url,
        catalog_source=profile.catalog_source,
        catalog_uri=profile.catalog_uri,
        bridge_uri=profile.bridge_uri,
        context_window=profile.context_window,
        account_routing=profile.account_routing,
        builtin=profile.builtin,
    )


def _normalize_profile_id(value: str) -> str:
    normalized = value.strip().lower()
    if not _PROFILE_ID.fullmatch(normalized):
        raise CodexProfileError("Codex profile id is invalid.")
    return normalized


def _validate_base_url(value: str) -> None:
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError as exc:
        raise CodexProfileError("Codex profile base URL is invalid.") from exc
    if (
        parsed.scheme not in {"http", "https"}
        or parsed.hostname is None
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
        or len(value) > 2048
    ):
        raise CodexProfileError("Codex profile base URL cannot contain credentials or query data.")
    if parsed.scheme == "http" and parsed.hostname not in {"127.0.0.1", "::1"}:
        raise CodexProfileError("Plain HTTP Codex profile endpoints must use numeric loopback.")
    if port is not None and not 1 <= port <= 65535:
        raise CodexProfileError("Codex profile base URL port is invalid.")


def _ordered_profiles(profiles: tuple[CodexProfile, ...]) -> tuple[CodexProfile, ...]:
    rank = {"openai-pool": 0, "ox": 1}
    return tuple(sorted(profiles, key=lambda item: (rank.get(item.id, 2), item.label.casefold(), item.id)))


def _harden(path: Path) -> None:
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


@lru_cache(maxsize=1)
def get_codex_profile_service() -> CodexProfileService:
    return CodexProfileService()
