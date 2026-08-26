from __future__ import annotations

from typing import Literal

from app.modules.shared.schemas import DashboardModel


class OpenHubClientConnectionResponse(DashboardModel):
    client: Literal["codex", "hermes", "opencode"]
    openai_base_url: str
    chatgpt_base_url: str | None = None
    wire_apis: list[Literal["responses", "chat_completions"]]
    credential_owner: Literal["openhub"] = "openhub"


class OpenHubRouterLimitsResponse(DashboardModel):
    global_response_creates: int | None
    per_account_response_creates: int | None
    per_account_streams: int | None
    proxy_requests: int | None


class OpenHubIntegrationStatusResponse(DashboardModel):
    product: Literal["OpenHUB"] = "OpenHUB"
    shared_base_url: str
    chatgpt_base_url: str
    models_url: str
    loopback_only: Literal[True] = True
    account_routing: Literal["request_time"] = "request_time"
    requires_client_restart_on_rotation: Literal[False] = False
    clients: list[OpenHubClientConnectionResponse]
    limits: OpenHubRouterLimitsResponse
