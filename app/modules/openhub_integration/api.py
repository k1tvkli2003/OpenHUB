from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.core.auth.dependencies import set_dashboard_error_format, validate_dashboard_session
from app.core.exceptions import DashboardBadRequestError
from app.modules.openhub_integration.schemas import (
    OpenHubClientConnectionResponse,
    OpenHubIntegrationStatusResponse,
    OpenHubRouterLimitsResponse,
)
from app.modules.openhub_integration.service import OpenHubIntegrationError, integration_snapshot

router = APIRouter(
    prefix="/api/openhub-integration",
    tags=["dashboard"],
    dependencies=[Depends(validate_dashboard_session), Depends(set_dashboard_error_format)],
)


@router.get("/status", response_model=OpenHubIntegrationStatusResponse)
async def get_openhub_integration_status(
    endpoint: str = Query(min_length=1, max_length=2048),
) -> OpenHubIntegrationStatusResponse:
    try:
        snapshot = integration_snapshot(endpoint)
    except OpenHubIntegrationError as exc:
        raise DashboardBadRequestError(str(exc), code="openhub_integration_error") from exc
    clients = [
        OpenHubClientConnectionResponse(
            client="codex",
            openai_base_url=snapshot.shared_base_url,
            chatgpt_base_url=snapshot.chatgpt_base_url,
            wire_apis=["responses", "chat_completions"],
        ),
        OpenHubClientConnectionResponse(
            client="hermes",
            openai_base_url=snapshot.shared_base_url,
            wire_apis=["responses", "chat_completions"],
        ),
        OpenHubClientConnectionResponse(
            client="opencode",
            openai_base_url=snapshot.shared_base_url,
            wire_apis=["responses", "chat_completions"],
        ),
    ]
    return OpenHubIntegrationStatusResponse(
        shared_base_url=snapshot.shared_base_url,
        chatgpt_base_url=snapshot.chatgpt_base_url,
        models_url=snapshot.models_url,
        clients=clients,
        limits=OpenHubRouterLimitsResponse(
            global_response_creates=snapshot.limits.global_response_creates,
            per_account_response_creates=snapshot.limits.per_account_response_creates,
            per_account_streams=snapshot.limits.per_account_streams,
            proxy_requests=snapshot.limits.proxy_requests,
        ),
    )
