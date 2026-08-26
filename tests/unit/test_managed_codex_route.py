from __future__ import annotations

from types import SimpleNamespace
from typing import Any

import pytest
from starlette.requests import HTTPConnection

from app.core.auth import dependencies as auth_dependencies
from app.core.exceptions import ProxyAuthError
from app.core.managed_codex_route import managed_codex_route_active
from app.core.middleware.managed_codex_route import ManagedCodexRouteMiddleware
from app.core.socket_peer import _capture_raw_socket_peer


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("peer", "request_path", "expected_active", "expected_path"),
    [
        (
            "127.0.0.1",
            "/backend-api/codex-managed/v1/responses",
            True,
            "/backend-api/codex/v1/responses",
        ),
        (
            "::1",
            "/backend-api/codex-managed/codex/responses",
            True,
            "/backend-api/codex/responses",
        ),
        (
            "127.0.0.1",
            "/backend-api/codex-managed/codex/models",
            True,
            "/backend-api/codex/models",
        ),
        (
            "192.0.2.10",
            "/backend-api/codex-managed/v1/responses",
            False,
            "/backend-api/codex-managed/v1/responses",
        ),
        (
            "localhost",
            "/backend-api/codex-managed/codex/responses",
            False,
            "/backend-api/codex-managed/codex/responses",
        ),
    ],
)
async def test_managed_path_requires_numeric_raw_loopback_and_is_consumed(
    peer: str,
    request_path: str,
    expected_active: bool,
    expected_path: str,
) -> None:
    observed: dict[str, Any] = {}

    async def inner(scope, _receive, _send) -> None:
        observed["active"] = managed_codex_route_active()
        observed["path"] = scope["path"]
        observed["raw_path"] = scope["raw_path"]

    middleware = ManagedCodexRouteMiddleware(inner)
    scope: dict[str, Any] = {
        "type": "http",
        "path": request_path,
        "raw_path": request_path.encode(),
        "headers": [(b"content-type", b"application/json")],
        "client": (peer, 4242),
    }
    _capture_raw_socket_peer(scope)

    await middleware(scope, None, None)

    assert observed["active"] is expected_active
    assert observed["path"] == expected_path
    assert observed["raw_path"] == expected_path.encode()
    assert managed_codex_route_active() is False


@pytest.mark.asyncio
async def test_ordinary_codex_path_is_never_treated_as_managed() -> None:
    observed: dict[str, Any] = {}

    async def inner(scope, _receive, _send) -> None:
        observed["active"] = managed_codex_route_active()
        observed["path"] = scope["path"]

    scope: dict[str, Any] = {
        "type": "websocket",
        "path": "/backend-api/codex/v1/responses",
        "raw_path": b"/backend-api/codex/v1/responses",
        "headers": [],
        "client": ("127.0.0.1", 4242),
    }
    _capture_raw_socket_peer(scope)

    await ManagedCodexRouteMiddleware(inner)(scope, None, None)

    assert observed == {"active": False, "path": "/backend-api/codex/v1/responses"}


class _ApiAuthEnabledSettingsCache:
    async def get(self) -> SimpleNamespace:
        return SimpleNamespace(api_key_auth_enabled=True)


@pytest.mark.asyncio
async def test_trusted_managed_route_bypasses_hub_api_key_validation(monkeypatch) -> None:
    observed: dict[str, Any] = {}
    monkeypatch.setattr(
        auth_dependencies,
        "get_settings_cache",
        lambda: _ApiAuthEnabledSettingsCache(),
    )

    async def inner(scope, _receive, _send) -> None:
        observed["result"] = await auth_dependencies.validate_proxy_api_key_authorization(
            "Bearer codex-desktop-session",
            request=HTTPConnection(scope),
        )

    request_path = "/backend-api/codex-managed/v1/models"
    scope: dict[str, Any] = {
        "type": "http",
        "path": request_path,
        "raw_path": request_path.encode(),
        "headers": [],
        "client": ("127.0.0.1", 4242),
    }
    _capture_raw_socket_peer(scope)

    await ManagedCodexRouteMiddleware(inner)(scope, None, None)

    assert observed["result"] is None
    assert managed_codex_route_active() is False


@pytest.mark.asyncio
async def test_remote_managed_path_does_not_bypass_hub_api_key_validation(monkeypatch) -> None:
    monkeypatch.setattr(
        auth_dependencies,
        "get_settings_cache",
        lambda: _ApiAuthEnabledSettingsCache(),
    )

    async def inner(scope, _receive, _send) -> None:
        await auth_dependencies.validate_proxy_api_key_authorization(
            None,
            request=HTTPConnection(scope),
        )

    request_path = "/backend-api/codex-managed/v1/models"
    scope: dict[str, Any] = {
        "type": "http",
        "path": request_path,
        "raw_path": request_path.encode(),
        "headers": [],
        "client": ("192.0.2.10", 4242),
    }
    _capture_raw_socket_peer(scope)

    with pytest.raises(ProxyAuthError, match="Missing API key"):
        await ManagedCodexRouteMiddleware(inner)(scope, None, None)

    assert managed_codex_route_active() is False
