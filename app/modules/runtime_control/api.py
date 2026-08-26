from __future__ import annotations

from anyio import to_thread
from fastapi import APIRouter, Depends, Request

from app.core.audit.service import AuditService
from app.core.auth.dependencies import (
    require_dashboard_write_access,
    set_dashboard_error_format,
    validate_dashboard_session,
)
from app.core.exceptions import DashboardBadRequestError, DashboardConflictError
from app.modules.runtime_control.gateway import RuntimeActionError, get_runtime_action_service
from app.modules.runtime_control.schemas import (
    RuntimeActionCapabilitiesResponse,
    RuntimeActionResponse,
    RuntimeControlSnapshotResponse,
    RuntimeHealthResponse,
    RuntimeTaskResponse,
    RuntimeTaskUsageResponse,
    RuntimeUsageResponse,
    RuntimeUsageWindowResponse,
)
from app.modules.runtime_control.service import (
    RuntimeTask,
    RuntimeUsage,
    UsageWindow,
    get_runtime_control_service,
)

router = APIRouter(
    prefix="/api/runtime-control",
    tags=["dashboard"],
    dependencies=[Depends(validate_dashboard_session), Depends(set_dashboard_error_format)],
)


@router.get("/snapshot", response_model=RuntimeControlSnapshotResponse)
async def get_runtime_snapshot() -> RuntimeControlSnapshotResponse:
    snapshot = await to_thread.run_sync(get_runtime_control_service().snapshot)
    return RuntimeControlSnapshotResponse(
        sampled_at=_iso(snapshot.sampled_at),
        reconnect_grace_seconds=snapshot.reconnect_grace_seconds,
        tasks=[_task_response(task) for task in snapshot.tasks],
        health=[
            RuntimeHealthResponse(
                runtime=item.runtime,
                status=item.status,
                database_path=str(item.database_path),
                gateway_reachable=item.gateway_reachable,
                reconnect_deadline=_iso(item.reconnect_deadline),
                message=item.message,
            )
            for item in snapshot.health
        ],
        usage=RuntimeUsageResponse(
            total=_window_response(snapshot.usage_total),
            codex=_window_response(snapshot.usage_codex),
            hermes=_window_response(snapshot.usage_hermes),
            opencode=_window_response(snapshot.usage_opencode),
        ),
    )


@router.post(
    "/tasks/{runtime}/{native_id}/{action}",
    response_model=RuntimeActionResponse,
)
async def control_runtime_task(
    request: Request,
    runtime: str,
    native_id: str,
    action: str,
    _write_access=Depends(require_dashboard_write_access),
) -> RuntimeActionResponse:
    try:
        result = await get_runtime_action_service().execute(runtime, native_id, action)
    except RuntimeActionError as exc:
        error_type = DashboardConflictError if exc.unsupported else DashboardBadRequestError
        raise error_type(str(exc), code=exc.code) from exc
    AuditService.log_async(
        "runtime_task_controlled",
        actor_ip=request.client.host if request.client else None,
        details={"runtime": result.runtime, "native_id": result.native_id, "action": result.action},
    )
    return RuntimeActionResponse(
        runtime=result.runtime,
        native_id=result.native_id,
        action=result.action,
        detail=result.detail,
    )


def _task_response(task: RuntimeTask) -> RuntimeTaskResponse:
    return RuntimeTaskResponse(
        id=task.id,
        native_id=task.native_id,
        runtime=task.runtime,
        root_id=task.root_id,
        parent_id=task.parent_id,
        is_root=task.is_root,
        child_count=task.child_count,
        title=task.title,
        cwd=task.cwd,
        provider=task.provider,
        model=task.model,
        state=task.state,
        started_at=_iso(task.started_at),
        last_activity_at=_iso(task.last_activity_at),
        ended_at=_iso(task.ended_at),
        usage=_usage_response(task.usage),
        aggregate_usage=_usage_response(task.aggregate_usage),
        capabilities=RuntimeActionCapabilitiesResponse(
            open=task.capabilities.open,
            pause=task.capabilities.pause,
            resume=task.capabilities.resume,
            stop=task.capabilities.stop,
        ),
        uncertain=task.uncertain,
        error_summary=task.error_summary,
    )


def _usage_response(usage: RuntimeUsage) -> RuntimeTaskUsageResponse:
    return RuntimeTaskUsageResponse(
        input_tokens=usage.input_tokens,
        output_tokens=usage.output_tokens,
        cache_read_tokens=usage.cache_read_tokens,
        cache_write_tokens=usage.cache_write_tokens,
        reasoning_tokens=usage.reasoning_tokens,
        total_tokens=usage.total_tokens,
        session_tokens=usage.session_tokens,
    )


def _window_response(window: UsageWindow) -> RuntimeUsageWindowResponse:
    return RuntimeUsageWindowResponse(
        since_start=window.since_start,
        last_minute=window.last_minute,
        last_hour=window.last_hour,
        started_at=_iso(window.started_at) or "",
    )


def _iso(value) -> str | None:
    return None if value is None else value.isoformat().replace("+00:00", "Z")
