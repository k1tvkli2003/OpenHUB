from __future__ import annotations

from typing import Literal

from pydantic import Field

from app.modules.shared.schemas import DashboardModel


class CodexIntegrationStatusResponse(DashboardModel):
    state_path: str
    enabled: bool
    revision: int
    managed_base_url: str
    toggled_at: str | None = None
    codex_state_policy: Literal["never_mutate"]


class CodexIntegrationModeRequest(DashboardModel):
    endpoint: str = Field(min_length=1, max_length=2048)
    expected_revision: int = Field(ge=0)
    enabled: bool
    confirmed: Literal[True]


class CodexIntegrationMutationResponse(CodexIntegrationStatusResponse):
    changed: bool


class CodexLaunchRouteResponse(DashboardModel):
    prepared: bool
    selection_mode: Literal["auto", "manual"] | None = None
    account_id: str | None = None
    account_label: str | None = None
    account_email: str | None = None
    plan_type: str | None = None
    effective_remaining_percent: float | None = None
    primary_remaining_percent: float | None = None
    secondary_remaining_percent: float | None = None
    monthly_remaining_percent: float | None = None
    limiting_remaining_credits: float | None = None
    sampled_at: str | None = None
    prepared_at: str | None = None
    revision: int


class CodexLaunchCandidateResponse(DashboardModel):
    account_id: str
    account_label: str
    account_email: str
    plan_type: str
    effective_remaining_percent: float
    primary_remaining_percent: float | None = None
    secondary_remaining_percent: float | None = None
    monthly_remaining_percent: float | None = None
    limiting_remaining_credits: float | None = None
    sampled_at: str


class CodexLaunchExclusionResponse(DashboardModel):
    account_id: str
    account_label: str
    reason: str


class CodexLaunchPrepareRequest(DashboardModel):
    endpoint: str = Field(min_length=1, max_length=2048)
    expected_revision: int = Field(ge=0)
    account_id: str | None = Field(default=None, min_length=1, max_length=256)
    confirmed: Literal[True]


class CodexLaunchPrepareResponse(DashboardModel):
    ready_to_launch: bool
    changed: bool
    route: CodexLaunchRouteResponse
    candidates: list[CodexLaunchCandidateResponse] = Field(default_factory=list)
    exclusions: list[CodexLaunchExclusionResponse] = Field(default_factory=list)
