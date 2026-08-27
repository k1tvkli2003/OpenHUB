from __future__ import annotations

from contextvars import ContextVar, Token

OPENHUB_SHARED_ROUTE_PATH_PREFIX = "/backend-api/openhub"

_ACTIVE: ContextVar[bool] = ContextVar("openhub_shared_route_active", default=False)


def openhub_shared_route_active() -> bool:
    return _ACTIVE.get()


def set_openhub_shared_route_active(value: bool) -> Token[bool]:
    return _ACTIVE.set(value)


def reset_openhub_shared_route_active(token: Token[bool]) -> None:
    _ACTIVE.reset(token)


__all__ = [
    "OPENHUB_SHARED_ROUTE_PATH_PREFIX",
    "openhub_shared_route_active",
    "reset_openhub_shared_route_active",
    "set_openhub_shared_route_active",
]
