from __future__ import annotations

from ipaddress import ip_address
from typing import Any, cast

from fastapi import FastAPI
from starlette.requests import HTTPConnection
from starlette.types import ASGIApp, Receive, Scope, Send

from app.core.managed_codex_route import (
    MANAGED_CODEX_ROUTE_PATH_PREFIX,
    reset_managed_codex_route_active,
    set_managed_codex_route_active,
)
from app.core.socket_peer import raw_socket_peer_host

_UPSTREAM_PATH_PREFIX = "/backend-api/codex"


class ManagedCodexRouteMiddleware:
    """Trust and consume the dedicated managed URL path only on loopback."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        active = False
        inner_scope = scope
        path = str(scope.get("path", ""))
        if scope["type"] in {"http", "websocket"} and _has_managed_prefix(path):
            peer = raw_socket_peer_host(HTTPConnection(scope))
            if peer is not None and _is_numeric_loopback(peer):
                active = True
                suffix = path[len(MANAGED_CODEX_ROUTE_PATH_PREFIX) :]
                # ``chatgpt_base_url`` is a ChatGPT API root. Codex appends its
                # own ``/codex/...`` route to that root, while
                # ``openai_base_url`` appends ``/v1/...``. Both managed launch
                # overrides intentionally share one marker, so normalize the
                # ChatGPT-owned segment before entering openhub's canonical
                # ``/backend-api/codex`` router.
                if suffix == "/codex":
                    suffix = ""
                elif suffix.startswith("/codex/"):
                    suffix = suffix[len("/codex") :]
                rewritten = f"{_UPSTREAM_PATH_PREFIX}{suffix}"
                inner_scope = dict(scope)
                inner_scope["path"] = rewritten
                inner_scope["raw_path"] = rewritten.encode("utf-8")

        token = set_managed_codex_route_active(active)
        try:
            await self.app(cast(Scope, inner_scope), receive, send)
        finally:
            reset_managed_codex_route_active(token)


def _has_managed_prefix(path: str) -> bool:
    return path == MANAGED_CODEX_ROUTE_PATH_PREFIX or path.startswith(f"{MANAGED_CODEX_ROUTE_PATH_PREFIX}/")


def _is_numeric_loopback(host: str) -> bool:
    try:
        return ip_address(host).is_loopback
    except ValueError:
        return False


def add_managed_codex_route_middleware(app: FastAPI) -> None:
    app.add_middleware(cast(Any, ManagedCodexRouteMiddleware))


__all__ = ["ManagedCodexRouteMiddleware", "add_managed_codex_route_middleware"]
