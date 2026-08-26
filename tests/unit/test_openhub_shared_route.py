from __future__ import annotations

from types import SimpleNamespace
from typing import Any

import pytest
from starlette.requests import HTTPConnection

from app.core.auth import dependencies as auth_dependencies
from app.core.exceptions import ProxyAuthError
from app.core.middleware.openhub_shared_route import OpenHubSharedRouteMiddleware
from app.core.openhub_shared_route import openhub_shared_route_active
from app.core.socket_peer import _capture_raw_socket_peer


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("peer", "request_path", "expected_active", "expected_path"),
    [
        (
            "127.0.0.1",
            "/backend-api/openhub/v1/responses",
            True,
            "/backend-api/codex/v1/responses",
        ),
        (
            "::1",
            "/backend-api/openhub/codex/models",
            True,
            "/backend-api/codex/models",
        ),
        (
            "192.0.2.10",
            "/backend-api/openhub/v1/models",
            False,
            "/backend-api/openhub/v1/models",
        ),
    ],
)
async def test_shared_route_is_loopback_only_and_consumed(
    peer: str,
    request_path: str,
    expected_active: bool,
    expected_path: str,
) -> None:
    observed: dict[str, Any] = {}

    async def inner(scope, _receive, _send) -> None:
        observed["active"] = openhub_shared_route_active()
        observed["path"] = scope["path"]

    scope: dict[str, Any] = {
        "type": "http",
        "path": request_path,
        "raw_path": request_path.encode(),
        "headers": [],
        "client": (peer, 4242),
    }
    _capture_raw_socket_peer(scope)
    await OpenHubSharedRouteMiddleware(inner)(scope, None, None)

    assert observed == {"active": expected_active, "path": expected_path}
    assert openhub_shared_route_active() is False


class _ApiAuthEnabledSettingsCache:
    async def get(self) -> SimpleNamespace:
        return SimpleNamespace(api_key_auth_enabled=True)


@pytest.mark.asyncio
async def test_shared_route_bypasses_hub_api_key_only_on_raw_loopback(monkeypatch) -> None:
    monkeypatch.setattr(
        auth_dependencies,
        "get_settings_cache",
        lambda: _ApiAuthEnabledSettingsCache(),
    )
    observed: dict[str, object] = {}

    async def inner(scope, _receive, _send) -> None:
        authorization = (
            "Bearer client-owned-placeholder"
            if openhub_shared_route_active()
            else None
        )
        observed["result"] = await auth_dependencies.validate_proxy_api_key_authorization(
            authorization,
            request=HTTPConnection(scope),
        )

    path = "/backend-api/openhub/v1/models"
    scope: dict[str, Any] = {
        "type": "http",
        "path": path,
        "raw_path": path.encode(),
        "headers": [],
        "client": ("127.0.0.1", 4242),
    }
    _capture_raw_socket_peer(scope)
    await OpenHubSharedRouteMiddleware(inner)(scope, None, None)
    assert observed["result"] is None

    remote_scope = dict(scope)
    remote_scope["client"] = ("192.0.2.10", 4242)
    _capture_raw_socket_peer(remote_scope)
    with pytest.raises(ProxyAuthError, match="Missing API key"):
        await OpenHubSharedRouteMiddleware(inner)(remote_scope, None, None)
