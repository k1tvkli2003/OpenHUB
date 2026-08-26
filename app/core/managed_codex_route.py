from __future__ import annotations

from contextvars import ContextVar, Token

MANAGED_CODEX_ROUTE_PATH_PREFIX = "/backend-api/codex-managed"

_ACTIVE: ContextVar[bool] = ContextVar("managed_codex_route_active", default=False)


def managed_codex_route_active() -> bool:
    return _ACTIVE.get()


def set_managed_codex_route_active(value: bool) -> Token[bool]:
    return _ACTIVE.set(value)


def reset_managed_codex_route_active(token: Token[bool]) -> None:
    _ACTIVE.reset(token)


__all__ = [
    "MANAGED_CODEX_ROUTE_PATH_PREFIX",
    "managed_codex_route_active",
    "reset_managed_codex_route_active",
    "set_managed_codex_route_active",
]
