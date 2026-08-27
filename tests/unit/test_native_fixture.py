from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from app.core.native_fixture import NativeFixtureValidationError, validate_native_fixture_data_dir


def _path_hash(path: Path) -> str:
    return hashlib.sha256(str(path.resolve()).casefold().encode()).hexdigest()


def _write_fixture(fixture: Path, home: Path) -> None:
    fixture.mkdir(parents=True)
    files = {
        "store.db": b"fixture-database",
        "encryption.key": b"fixture-key",
    }
    for name, data in files.items():
        (fixture / name).write_bytes(data)
    marker = {
        "schema_version": 1,
        "fixture_id": "fixture-id",
        "fixture_path": str(fixture.resolve()),
        "fixture_path_sha256": _path_hash(fixture),
        "live_path_sha256": _path_hash(home.resolve() / ".openhub"),
        "files": {name: hashlib.sha256(data).hexdigest() for name, data in files.items()},
    }
    (fixture / ".openhub-native-test-fixture.json").write_text(json.dumps(marker), encoding="utf-8")


def test_native_fixture_validation_accepts_bound_hash_verified_copy(tmp_path: Path) -> None:
    home = tmp_path / "home"
    fixture = tmp_path / "fixtures" / "copy"
    _write_fixture(fixture, home)

    validate_native_fixture_data_dir(fixture, home=home)


def test_native_fixture_validation_rejects_tampered_database(tmp_path: Path) -> None:
    home = tmp_path / "home"
    fixture = tmp_path / "fixtures" / "copy"
    _write_fixture(fixture, home)
    (fixture / "store.db").write_bytes(b"changed")

    with pytest.raises(NativeFixtureValidationError, match="hash verification"):
        validate_native_fixture_data_dir(fixture, home=home)


def test_native_fixture_validation_rejects_live_path_before_start(tmp_path: Path) -> None:
    home = tmp_path / "home"
    live = home / ".openhub"
    _write_fixture(live, home)

    with pytest.raises(NativeFixtureValidationError, match="refuses the live"):
        validate_native_fixture_data_dir(live, home=home)


def test_native_fixture_validation_rejects_a_moved_marker(tmp_path: Path) -> None:
    home = tmp_path / "home"
    source = tmp_path / "fixtures" / "source"
    moved = tmp_path / "fixtures" / "moved"
    _write_fixture(source, home)
    moved.mkdir(parents=True)
    for name in ("store.db", "encryption.key", ".openhub-native-test-fixture.json"):
        (moved / name).write_bytes((source / name).read_bytes())

    with pytest.raises(NativeFixtureValidationError, match="recorded identity"):
        validate_native_fixture_data_dir(moved, home=home)
