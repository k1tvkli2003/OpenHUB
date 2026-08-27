from __future__ import annotations

from dataclasses import dataclass
from ipaddress import ip_address
from urllib.parse import urlsplit

from app.core.config.settings import Settings, get_settings

_SHARED_PATH = "/backend-api/openhub/v1"
_CHATGPT_PATH = "/backend-api/openhub"


class OpenHubIntegrationError(ValueError):
    pass


@dataclass(frozen=True, slots=True)
class OpenHubRouterLimits:
    global_response_creates: int | None
    per_account_response_creates: int | None
    per_account_streams: int | None
    proxy_requests: int | None


@dataclass(frozen=True, slots=True)
class OpenHubIntegrationSnapshot:
    shared_base_url: str
    chatgpt_base_url: str
    models_url: str
    limits: OpenHubRouterLimits


def integration_snapshot(endpoint: str, *, settings: Settings | None = None) -> OpenHubIntegrationSnapshot:
    normalized = _normalize_endpoint(endpoint)
    active_settings = settings or get_settings()
    shared_base_url = f"{normalized}{_SHARED_PATH}"
    return OpenHubIntegrationSnapshot(
        shared_base_url=shared_base_url,
        chatgpt_base_url=f"{normalized}{_CHATGPT_PATH}",
        models_url=f"{shared_base_url}/models",
        limits=OpenHubRouterLimits(
            global_response_creates=_positive_or_none(active_settings.proxy_response_create_limit),
            per_account_response_creates=_positive_or_none(
                active_settings.proxy_account_response_create_limit
            ),
            per_account_streams=_positive_or_none(active_settings.proxy_account_stream_limit),
            proxy_requests=_positive_or_none(active_settings.bulkhead_proxy_limit),
        ),
    )


def _positive_or_none(value: int) -> int | None:
    return value if value > 0 else None


def _normalize_endpoint(endpoint: str) -> str:
    candidate = endpoint.strip()
    try:
        parsed = urlsplit(candidate)
        port = parsed.port
    except ValueError as exc:
        raise OpenHubIntegrationError("The local OpenHUB endpoint is invalid.") from exc
    if parsed.scheme != "http" or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise OpenHubIntegrationError(
            "The shared endpoint requires plain HTTP numeric loopback without credentials."
        )
    if parsed.path not in {"", "/"} or parsed.hostname is None or port is None:
        raise OpenHubIntegrationError("The shared endpoint requires a loopback host and explicit port.")
    try:
        address = ip_address(parsed.hostname)
    except ValueError as exc:
        raise OpenHubIntegrationError("The shared endpoint accepts only a numeric loopback address.") from exc
    if not address.is_loopback:
        raise OpenHubIntegrationError("The shared endpoint rejects non-loopback addresses.")
    host = f"[{address.compressed}]" if address.version == 6 else address.compressed
    return f"http://{host}:{port}"


__all__ = [
    "OpenHubIntegrationError",
    "OpenHubIntegrationSnapshot",
    "OpenHubRouterLimits",
    "integration_snapshot",
]
