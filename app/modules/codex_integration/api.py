from __future__ import annotations

from datetime import UTC, datetime

from anyio import to_thread
from fastapi import APIRouter, Depends, Query, Request

from app.core.audit.service import AuditService
from app.core.auth.dependencies import (
    require_dashboard_write_access,
    set_dashboard_error_format,
    validate_dashboard_session,
)
from app.core.config.settings import get_settings
from app.core.exceptions import DashboardBadRequestError, DashboardConflictError
from app.dependencies import AccountsContext, get_accounts_context
from app.modules.codex_integration.launch_selection import (
    CodexLaunchCandidate,
    CodexLaunchExclusion,
    select_codex_launch_account,
)
from app.modules.codex_integration.schemas import (
    CodexIntegrationModeRequest,
    CodexIntegrationMutationResponse,
    CodexIntegrationStatusResponse,
    CodexLaunchCandidateResponse,
    CodexLaunchExclusionResponse,
    CodexLaunchPrepareRequest,
    CodexLaunchPrepareResponse,
    CodexLaunchRouteResponse,
)
from app.modules.codex_integration.service import (
    CodexIntegrationConflictError,
    CodexIntegrationError,
    CodexIntegrationMutation,
    CodexIntegrationSnapshot,
    CodexLaunchConflictError,
    CodexLaunchRoute,
    get_codex_integration_service,
)

router = APIRouter(
    prefix="/api/codex-integration",
    tags=["dashboard"],
    dependencies=[Depends(validate_dashboard_session), Depends(set_dashboard_error_format)],
)


@router.get("/status", response_model=CodexIntegrationStatusResponse)
async def get_codex_integration_status(
    endpoint: str = Query(min_length=1, max_length=2048),
) -> CodexIntegrationStatusResponse:
    try:
        snapshot = await to_thread.run_sync(lambda: get_codex_integration_service().status(endpoint))
    except CodexIntegrationError as exc:
        raise _dashboard_error(exc) from exc
    return _status_response(snapshot)


@router.post("/mode", response_model=CodexIntegrationMutationResponse)
async def set_codex_integration_mode(
    request: Request,
    payload: CodexIntegrationModeRequest,
    _write_access=Depends(require_dashboard_write_access),
) -> CodexIntegrationMutationResponse:
    try:
        mutation = await to_thread.run_sync(
            lambda: get_codex_integration_service().set_enabled(
                endpoint=payload.endpoint,
                expected_revision=payload.expected_revision,
                enabled=payload.enabled,
            )
        )
    except CodexIntegrationError as exc:
        raise _dashboard_error(exc) from exc
    AuditService.log_async(
        "codex_managed_launch_mode_changed",
        actor_ip=request.client.host if request.client else None,
        details={
            "enabled": mutation.snapshot.enabled,
            "changed": mutation.changed,
            "revision": mutation.snapshot.revision,
        },
    )
    return _mutation_response(mutation)


@router.get("/launch-route", response_model=CodexLaunchRouteResponse)
async def get_codex_launch_route() -> CodexLaunchRouteResponse:
    try:
        route = await to_thread.run_sync(get_codex_integration_service().launch_route_snapshot)
    except CodexIntegrationError as exc:
        raise _dashboard_error(exc) from exc
    return _launch_route_response(route)


@router.post("/prepare-launch", response_model=CodexLaunchPrepareResponse)
async def prepare_codex_launch(
    request: Request,
    payload: CodexLaunchPrepareRequest,
    context: AccountsContext = Depends(get_accounts_context),
    _write_access=Depends(require_dashboard_write_access),
) -> CodexLaunchPrepareResponse:
    service = get_codex_integration_service()
    try:
        integration = await to_thread.run_sync(lambda: service.status(payload.endpoint))
        current_route = await to_thread.run_sync(service.launch_route_snapshot)
    except CodexIntegrationError as exc:
        raise _dashboard_error(exc) from exc
    manual_account_id = payload.account_id
    if manual_account_id is None and not integration.enabled:
        raise DashboardConflictError(
            "Automatic routing is disabled in OpenHUB.",
            code="codex_managed_routing_disabled",
        )
    if current_route.revision != payload.expected_revision:
        raise DashboardConflictError(
            "Codex launch preparation changed after it was loaded; refresh and try again.",
            code="codex_launch_conflict",
        )

    accounts = await context.service.refresh_usage_for_codex_launch()
    refresh_interval = max(1, int(get_settings().usage_refresh_interval_seconds))
    selection = select_codex_launch_account(
        accounts,
        now=datetime.now(UTC),
        max_sample_age_seconds=max(300, refresh_interval * 2),
    )
    candidate_responses = [_candidate_response(candidate) for candidate in selection.candidates]
    exclusion_responses = [_exclusion_response(exclusion) for exclusion in selection.exclusions]
    selected = selection.selected
    selection_mode = "auto"
    if manual_account_id is not None:
        selection_mode = "manual"
        selected = next(
            (candidate for candidate in selection.candidates if candidate.account_id == manual_account_id),
            None,
        )
        known_account = selected is not None or any(
            exclusion.account_id == manual_account_id for exclusion in selection.exclusions
        )
        if not known_account:
            raise DashboardBadRequestError(
                "The selected local account no longer exists.",
                code="codex_manual_account_not_found",
            )
        if selected is None:
            exclusion_responses = [
                _exclusion_response(exclusion)
                for exclusion in selection.exclusions
                if exclusion.account_id == manual_account_id
            ]
    if selected is None:
        AuditService.log_async(
            "codex_launch_preparation_blocked",
            actor_ip=request.client.host if request.client else None,
            details={"candidate_count": 0, "exclusion_count": len(exclusion_responses)},
        )
        return CodexLaunchPrepareResponse(
            ready_to_launch=False,
            changed=False,
            route=_launch_route_response(current_route),
            candidates=candidate_responses,
            exclusions=exclusion_responses,
        )

    try:
        mutation = await to_thread.run_sync(
            lambda: service.prepare_launch_route(
                endpoint=payload.endpoint,
                expected_revision=payload.expected_revision,
                selection_mode=selection_mode,
                account_id=selected.account_id,
                account_label=selected.account_label,
                account_email=selected.account_email,
                plan_type=selected.plan_type,
                effective_remaining_percent=selected.effective_remaining_percent,
                primary_remaining_percent=selected.primary_remaining_percent,
                secondary_remaining_percent=selected.secondary_remaining_percent,
                monthly_remaining_percent=selected.monthly_remaining_percent,
                limiting_remaining_credits=selected.limiting_remaining_credits,
                sampled_at=selected.sampled_at.isoformat().replace("+00:00", "Z"),
            )
        )
    except CodexIntegrationError as exc:
        raise _dashboard_error(exc) from exc
    AuditService.log_async(
        "codex_launch_prepared",
        actor_ip=request.client.host if request.client else None,
        details={
            "account_id": mutation.route.account_id,
            "selection_mode": selection_mode,
            "revision": mutation.route.revision,
            "effective_remaining_percent": mutation.route.effective_remaining_percent,
            "candidate_count": len(candidate_responses),
            "exclusion_count": len(exclusion_responses),
        },
    )
    return CodexLaunchPrepareResponse(
        ready_to_launch=True,
        changed=mutation.changed,
        route=_launch_route_response(mutation.route),
        candidates=candidate_responses,
        exclusions=exclusion_responses,
    )


def _launch_route_response(route: CodexLaunchRoute) -> CodexLaunchRouteResponse:
    return CodexLaunchRouteResponse(
        prepared=route.prepared,
        selection_mode=route.selection_mode,
        account_id=route.account_id,
        account_label=route.account_label,
        account_email=route.account_email,
        plan_type=route.plan_type,
        effective_remaining_percent=route.effective_remaining_percent,
        primary_remaining_percent=route.primary_remaining_percent,
        secondary_remaining_percent=route.secondary_remaining_percent,
        monthly_remaining_percent=route.monthly_remaining_percent,
        limiting_remaining_credits=route.limiting_remaining_credits,
        sampled_at=route.sampled_at,
        prepared_at=route.prepared_at,
        revision=route.revision,
    )


def _candidate_response(candidate: CodexLaunchCandidate) -> CodexLaunchCandidateResponse:
    return CodexLaunchCandidateResponse(
        account_id=candidate.account_id,
        account_label=candidate.account_label,
        account_email=candidate.account_email,
        plan_type=candidate.plan_type,
        effective_remaining_percent=candidate.effective_remaining_percent,
        primary_remaining_percent=candidate.primary_remaining_percent,
        secondary_remaining_percent=candidate.secondary_remaining_percent,
        monthly_remaining_percent=candidate.monthly_remaining_percent,
        limiting_remaining_credits=candidate.limiting_remaining_credits,
        sampled_at=candidate.sampled_at.isoformat().replace("+00:00", "Z"),
    )


def _exclusion_response(exclusion: CodexLaunchExclusion) -> CodexLaunchExclusionResponse:
    return CodexLaunchExclusionResponse(
        account_id=exclusion.account_id,
        account_label=exclusion.account_label,
        reason=exclusion.reason,
    )


def _status_response(snapshot: CodexIntegrationSnapshot) -> CodexIntegrationStatusResponse:
    return CodexIntegrationStatusResponse(
        state_path=str(snapshot.state_path),
        enabled=snapshot.enabled,
        revision=snapshot.revision,
        managed_base_url=snapshot.managed_base_url,
        toggled_at=snapshot.toggled_at,
        codex_state_policy="never_mutate",
    )


def _mutation_response(mutation: CodexIntegrationMutation) -> CodexIntegrationMutationResponse:
    status = _status_response(mutation.snapshot)
    return CodexIntegrationMutationResponse(**status.model_dump(), changed=mutation.changed)


def _dashboard_error(error: CodexIntegrationError):
    if isinstance(error, CodexLaunchConflictError):
        return DashboardConflictError(str(error), code="codex_launch_conflict")
    if isinstance(error, CodexIntegrationConflictError):
        return DashboardConflictError(str(error), code="codex_integration_conflict")
    return DashboardBadRequestError(str(error), code="codex_integration_error")
