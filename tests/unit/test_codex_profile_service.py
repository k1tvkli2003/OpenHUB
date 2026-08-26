from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.modules.codex_integration.profiles import (
    CodexProfile,
    CodexProfileConflictError,
    CodexProfileError,
    CodexProfileService,
)


def _custom_profile(**overrides: object) -> CodexProfile:
    values: dict[str, object] = {
        "id": "local-lab",
        "label": "Local lab",
        "kind": "custom",
        "model_provider": "local_lab",
        "model": "lab-coder",
        "wire_api": "responses",
        "base_url": "http://127.0.0.1:11434/v1",
        "catalog_source": "none",
        "catalog_uri": None,
        "bridge_uri": None,
        "context_window": 65536,
        "account_routing": "none",
        "builtin": False,
    }
    values.update(overrides)
    return CodexProfile(**values)  # type: ignore[arg-type]


def test_defaults_are_portable_and_do_not_write_until_mutated(tmp_path: Path) -> None:
    service = CodexProfileService(data_root=tmp_path / "data")

    registry = service.snapshot()

    assert registry.revision == 0
    assert registry.active_profile_id == "openai-pool"
    assert [profile.id for profile in registry.profiles] == ["openai-pool", "ox"]
    assert registry.profiles[0].catalog_source == "live_managed"
    assert registry.profiles[1].bridge_uri == "asset://ox/openhub-ox-adapter.mjs"
    assert not registry.state_path.exists()
    assert str(tmp_path) not in json.dumps([profile.__dict__ for profile in registry.profiles])


def test_custom_profile_round_trip_and_activation_are_revisioned(tmp_path: Path) -> None:
    service = CodexProfileService(data_root=tmp_path / "data")

    created = service.upsert(expected_revision=0, profile=_custom_profile())
    activated = service.activate(expected_revision=1, profile_id="local-lab")
    reloaded = CodexProfileService(data_root=tmp_path / "data").snapshot()

    assert created.changed is True
    assert activated.registry.active_profile_id == "local-lab"
    assert activated.registry.revision == 2
    assert reloaded == activated.registry


def test_profile_rejects_credentials_in_url_and_personal_asset_path(tmp_path: Path) -> None:
    service = CodexProfileService(data_root=tmp_path / "data")

    with pytest.raises(CodexProfileError, match="credentials"):
        service.upsert(
            expected_revision=0,
            profile=_custom_profile(base_url="https://token@example.invalid/v1"),
        )
    with pytest.raises(CodexProfileError, match="asset URI"):
        service.upsert(
            expected_revision=0,
            profile=_custom_profile(catalog_source="bundled", catalog_uri="C:/Users/name/catalog.json"),
        )


def test_builtin_and_active_profile_deletion_fail_closed(tmp_path: Path) -> None:
    service = CodexProfileService(data_root=tmp_path / "data")

    with pytest.raises(CodexProfileError, match="Built-in"):
        service.delete(expected_revision=0, profile_id="ox")

    service.upsert(expected_revision=0, profile=_custom_profile())
    service.activate(expected_revision=1, profile_id="local-lab")
    with pytest.raises(CodexProfileConflictError, match="active"):
        service.delete(expected_revision=2, profile_id="local-lab")


def test_stale_revision_does_not_overwrite_profile_state(tmp_path: Path) -> None:
    service = CodexProfileService(data_root=tmp_path / "data")
    service.upsert(expected_revision=0, profile=_custom_profile())

    with pytest.raises(CodexProfileConflictError):
        service.upsert(
            expected_revision=0,
            profile=_custom_profile(label="Stale overwrite"),
        )

    assert service.snapshot().revision == 1
    current = next(profile for profile in service.snapshot().profiles if profile.id == "local-lab")
    assert current.label == "Local lab"
