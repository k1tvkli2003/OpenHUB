from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from math import isfinite

from app.core.plan_types import is_free_account_plan
from app.modules.accounts.schemas import AccountSummary


@dataclass(frozen=True)
class CodexLaunchCandidate:
    account_id: str
    account_label: str
    account_email: str
    plan_type: str
    effective_remaining_percent: float
    primary_remaining_percent: float | None
    secondary_remaining_percent: float | None
    monthly_remaining_percent: float | None
    limiting_remaining_credits: float | None
    sampled_at: datetime


@dataclass(frozen=True)
class CodexLaunchExclusion:
    account_id: str
    account_label: str
    reason: str


@dataclass(frozen=True)
class CodexLaunchSelection:
    selected: CodexLaunchCandidate | None
    candidates: tuple[CodexLaunchCandidate, ...]
    exclusions: tuple[CodexLaunchExclusion, ...]


def select_codex_launch_account(
    accounts: list[AccountSummary],
    *,
    now: datetime,
    max_sample_age_seconds: int,
) -> CodexLaunchSelection:
    now_utc = _as_utc(now)
    candidates: list[CodexLaunchCandidate] = []
    exclusions: list[CodexLaunchExclusion] = []
    for account in accounts:
        label = account.display_name or account.alias or account.email
        reason = _exclusion_reason(
            account,
            now=now_utc,
            max_sample_age_seconds=max_sample_age_seconds,
        )
        if reason is not None:
            exclusions.append(CodexLaunchExclusion(account.account_id, label, reason))
            continue
        assert account.usage is not None
        assert account.usage_sample_at is not None
        remaining = _known_usage_windows(account)
        assert remaining
        credit_values = [
            value
            for value in (
                account.remaining_credits_primary,
                account.remaining_credits_secondary,
                account.remaining_credits_monthly,
            )
            if value is not None and isfinite(float(value))
        ]
        candidates.append(
            CodexLaunchCandidate(
                account_id=account.account_id,
                account_label=label,
                account_email=account.email,
                plan_type=account.plan_type,
                effective_remaining_percent=min(float(value) for value in remaining),
                primary_remaining_percent=_finite_or_none(account.usage.primary_remaining_percent),
                secondary_remaining_percent=_finite_or_none(account.usage.secondary_remaining_percent),
                monthly_remaining_percent=_finite_or_none(account.usage.monthly_remaining_percent),
                limiting_remaining_credits=min(float(value) for value in credit_values) if credit_values else None,
                sampled_at=_as_utc(account.usage_sample_at),
            )
        )

    ranked = tuple(
        sorted(
            candidates,
            key=lambda candidate: (
                -candidate.effective_remaining_percent,
                -(candidate.limiting_remaining_credits or 0.0),
                -candidate.sampled_at.timestamp(),
                candidate.account_id,
            ),
        )
    )
    return CodexLaunchSelection(
        selected=ranked[0] if ranked else None,
        candidates=ranked,
        exclusions=tuple(sorted(exclusions, key=lambda item: item.account_id)),
    )


def _exclusion_reason(
    account: AccountSummary,
    *,
    now: datetime,
    max_sample_age_seconds: int,
) -> str | None:
    if is_free_account_plan(account.plan_type):
        return "free_plan_not_routable"
    if account.status != "active":
        return f"account_{account.status}"
    if account.usage is None:
        return "usage_all_windows_unknown"
    raw_windows = (
        account.usage.primary_remaining_percent,
        account.usage.secondary_remaining_percent,
        account.usage.monthly_remaining_percent,
    )
    if any(value is not None and _finite_or_none(value) is None for value in raw_windows):
        return "usage_sample_invalid"
    windows = _known_usage_windows(account)
    if not windows:
        return "usage_all_windows_unknown"
    if account.usage_sample_at is None:
        return "usage_sample_missing"
    sampled_at = _as_utc(account.usage_sample_at)
    age_seconds = max(0.0, (now - sampled_at).total_seconds())
    if age_seconds > max_sample_age_seconds:
        return "usage_sample_stale"
    if min(windows) <= 0.0:
        return "quota_exhausted"
    return None


def _known_usage_windows(account: AccountSummary) -> list[float]:
    if account.usage is None:
        return []
    return [
        float(value)
        for value in (
            account.usage.primary_remaining_percent,
            account.usage.secondary_remaining_percent,
            account.usage.monthly_remaining_percent,
        )
        if _finite_or_none(value) is not None
    ]


def _finite_or_none(value: float | None) -> float | None:
    if value is None:
        return None
    numeric = float(value)
    return numeric if isfinite(numeric) else None


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
