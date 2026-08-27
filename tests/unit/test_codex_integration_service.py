from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

from app.modules.codex_integration.service import (
    CodexIntegrationConflictError,
    CodexIntegrationError,
    CodexIntegrationService,
)

ENDPOINT = "http://127.0.0.1:2455"


def test_status_defaults_off_and_uses_only_hub_owned_state(tmp_path: Path) -> None:
    data_root = tmp_path / ".openhub"
    service = CodexIntegrationService(data_root=data_root)

    status = service.status(ENDPOINT)

    assert status.enabled is False
    assert status.revision == 0
    assert status.codex_state_policy == "never_mutate"
    assert status.state_path == data_root / "openhub-managed-launch.json"
    assert status.managed_base_url == f"{ENDPOINT}/backend-api/codex-managed/v1"
    assert not data_root.exists()


def test_enable_disable_and_manual_prepare_never_touch_codex_state(tmp_path: Path) -> None:
    data_root = tmp_path / ".openhub"
    codex_root = tmp_path / ".codex"
    codex_root.mkdir()
    protected = {
        codex_root / "config.toml": b'model = "gpt-5"\n',
        codex_root / "auth.json": b'{"fixture":"do-not-touch"}\n',
        codex_root / "state_5.sqlite": b"sqlite-fixture",
        codex_root / "history.jsonl": b'{"thread":"fixture"}\n',
    }
    for path, content in protected.items():
        path.write_bytes(content)
    before = {path: _sha256(path.read_bytes()) for path in protected}
    service = CodexIntegrationService(data_root=data_root)

    enabled = service.set_enabled(endpoint=ENDPOINT, expected_revision=0, enabled=True)
    route = service.prepare_launch_route(
        endpoint=ENDPOINT,
        expected_revision=0,
        selection_mode="manual",
        account_id="account-selected",
        account_label="Selected account",
        account_email="selected@example.invalid",
        plan_type="plus",
        effective_remaining_percent=71.0,
        primary_remaining_percent=71.0,
        secondary_remaining_percent=84.0,
        monthly_remaining_percent=None,
        limiting_remaining_credits=None,
        sampled_at="2026-08-10T12:00:00Z",
    )
    disabled = service.set_enabled(endpoint=ENDPOINT, expected_revision=1, enabled=False)

    assert enabled.snapshot.enabled is True
    assert route.route.selection_mode == "manual"
    assert route.route.account_id == "account-selected"
    assert disabled.snapshot.enabled is False
    assert (data_root / "openhub-managed-launch.json").is_file()
    assert (data_root / "openhub-launch-route.json").is_file()
    assert {path: _sha256(path.read_bytes()) for path in protected} == before


def test_manual_prepare_is_independent_but_auto_requires_enabled(tmp_path: Path) -> None:
    service = CodexIntegrationService(data_root=tmp_path / ".openhub")
    common = {
        "endpoint": ENDPOINT,
        "expected_revision": 0,
        "account_id": "account-1",
        "account_label": "Account 1",
        "account_email": "one@example.invalid",
        "plan_type": "plus",
        "effective_remaining_percent": 50.0,
        "primary_remaining_percent": 50.0,
        "secondary_remaining_percent": None,
        "monthly_remaining_percent": None,
        "limiting_remaining_credits": None,
        "sampled_at": "2026-08-10T12:00:00Z",
    }

    with pytest.raises(CodexIntegrationConflictError, match="Automatic routing is disabled"):
        service.prepare_launch_route(selection_mode="auto", **common)

    manual = service.prepare_launch_route(selection_mode="manual", **common)
    assert manual.route.selection_mode == "manual"


def test_mode_revision_conflict_fails_without_write(tmp_path: Path) -> None:
    service = CodexIntegrationService(data_root=tmp_path / ".openhub")
    service.set_enabled(endpoint=ENDPOINT, expected_revision=0, enabled=True)

    with pytest.raises(CodexIntegrationConflictError):
        service.set_enabled(endpoint=ENDPOINT, expected_revision=0, enabled=False)

    assert service.status(ENDPOINT).enabled is True


@pytest.mark.parametrize(
    "endpoint",
    [
        "https://127.0.0.1:2455",
        "http://localhost:2455",
        "http://192.0.2.1:2455",
        "http://127.0.0.1",
        "http://127.0.0.1:2455/path",
    ],
)
def test_status_rejects_noncanonical_endpoint(tmp_path: Path, endpoint: str) -> None:
    service = CodexIntegrationService(data_root=tmp_path / ".openhub")

    with pytest.raises(CodexIntegrationError):
        service.status(endpoint)


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()
