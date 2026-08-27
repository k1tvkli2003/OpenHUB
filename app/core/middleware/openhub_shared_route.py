from __future__ import annotations

from ipaddress import ip_address
from typing import Any, cast

from fastapi import FastAPI
from starlette.requests import HTTPConnection
from starlette.types import ASGIApp, Receive, Scope, Send

from app.core.openhub_shared_route import (
    OPENHUB_SHARED_ROUTE_PATH_PREFIX,
    reset_openhub_shared_route_active,
    set_openhub_shared_route_active,
)
from app.core.socket_peer import raw_socket_peer_host

_UPSTREAM_PATH_PREFIX = "/backend-api/codex"


class OpenHubSharedRouteMiddleware:
    """Expose the account router to local agent clients without launch pinning.

    The private alias is consumed only for a numeric raw-loopback socket peer.
    Unlike the legacy managed-Codex route, it deliberately does not activate a
    preselected launch account: every request enters normal request-time load
    balancing, so independent Codex and Hermes tasks remain concurrent.
    """

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        active = False
        inner_scope = scope
        path = str(scope.get("path", ""))
        if scope["type"] in {"http", "websocket"} and _has_shared_prefix(path):
            peer = raw_socket_peer_host(HTTPConnection(scope))
            if peer is not None and _is_numeric_loopback(peer):
                active = True
                suffix = path[len(OPENHUB_SHARED_ROUTE_PATH_PREFIX) :]
                if suffix == "/codex":
                    suffix = ""
                elif suffix.startswith("/codex/"):
                    suffix = suffix[len("/codex") :]
                rewritten = f"{_UPSTREAM_PATH_PREFIX}{suffix}"
                inner_scope = dict(scope)
                inner_scope["path"] = rewritten
                inner_scope["raw_path"] = rewritten.encode("utf-8")

        token = set_openhub_shared_route_active(active)
        try:
            await self.app(cast(Scope, inner_scope), receive, send)
        finally:
            reset_openhub_shared_route_active(token)


def _has_shared_prefix(path: str) -> bool:
    return path == OPENHUB_SHARED_ROUTE_PATH_PREFIX or path.startswith(
        f"{OPENHUB_SHARED_ROUTE_PATH_PREFIX}/"
    )


def _is_numeric_loopback(host: str) -> bool:
    try:
        return ip_address(host).is_loopback
    except ValueError:
        return False


def add_openhub_shared_route_middleware(app: FastAPI) -> None:
    app.add_middleware(cast(Any, OpenHubSharedRouteMiddleware))


__all__ = ["OpenHubSharedRouteMiddleware", "add_openhub_shared_route_middleware"]
