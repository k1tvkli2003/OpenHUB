from __future__ import annotations

from typing import Literal

from pydantic import Field

from app.modules.shared.schemas import DashboardModel

RuntimeId = Literal["codex", "hermes", "opencode"]
RuntimeTaskState = Literal[
    "queued",
    "active",
    "reasoning",
    "tool",
    "retrying",
    "reconnecting",
    "stalled",
    "failed",
    "cancelled",
    "idle",
    "unknown",
]


class RuntimeActionCapabilitiesResponse(DashboardModel):
    open: bool = False
    pause: bool = False
    resume: bool = False
    stop: bool = False


class RuntimeTaskUsageResponse(DashboardModel):
    input_tokens: int = Field(ge=0)
    output_tokens: int = Field(ge=0)
    cache_read_tokens: int = Field(ge=0)
    cache_write_tokens: int = Field(ge=0)
    reasoning_tokens: int = Field(ge=0)
    total_tokens: int = Field(ge=0)
    session_tokens: int = Field(ge=0)


class RuntimeTaskResponse(DashboardModel):
    id: str
    native_id: str
    runtime: RuntimeId
    root_id: str
    parent_id: str | None = None
    is_root: bool
    child_count: int = Field(ge=0)
    title: str
    cwd: str | None = None
    provider: str
    model: str
    state: RuntimeTaskState
    started_at: str | None = None
    last_activity_at: str | None = None
    ended_at: str | None = None
    usage: RuntimeTaskUsageResponse
    aggregate_usage: RuntimeTaskUsageResponse
    capabilities: RuntimeActionCapabilitiesResponse
    uncertain: bool = False
    error_summary: str | None = None


class RuntimeHealthResponse(DashboardModel):
    runtime: RuntimeId
    status: Literal["available", "reconnecting", "degraded", "unavailable"]
    database_path: str
    gateway_reachable: bool | None = None
    reconnect_deadline: str | None = None
    message: str | None = None


class RuntimeUsageWindowResponse(DashboardModel):
    since_start: int = Field(ge=0)
    last_minute: int = Field(ge=0)
    last_hour: int = Field(ge=0)
    started_at: str


class RuntimeUsageResponse(DashboardModel):
    total: RuntimeUsageWindowResponse
    codex: RuntimeUsageWindowResponse
    hermes: RuntimeUsageWindowResponse
    opencode: RuntimeUsageWindowResponse


class RuntimeControlSnapshotResponse(DashboardModel):
    sampled_at: str
    reconnect_grace_seconds: int = Field(ge=1)
    tasks: list[RuntimeTaskResponse]
    health: list[RuntimeHealthResponse]
    usage: RuntimeUsageResponse


class RuntimeActionResponse(DashboardModel):
    runtime: RuntimeId
    native_id: str
    action: Literal["pause", "resume", "stop"]
    succeeded: Literal[True] = True
    detail: str
