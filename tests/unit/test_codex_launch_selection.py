from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.modules.accounts.schemas import AccountSummary, AccountUsage
from app.modules.codex_integration.launch_selection import select_codex_launch_account

NOW = datetime(2026, 8, 9, 12, 0, tzinfo=UTC)


def _account(
    account_id: str,
    *,
    primary: float | None,
    secondary: float | None = None,
    monthly: float | None = None,
    status: str = "active",
    sampled_at: datetime | None = NOW,
    credits: float | None = None,
    plan_type: str = "pro",
) -> AccountSummary:
    return AccountSummary(
        account_id=account_id,
        email=f"{account_id}@example.test",
        display_name=account_id,
        plan_type=plan_type,
        status=status,
        usage=AccountUsage(
            primary_remaining_percent=primary,
            secondary_remaining_percent=secondary,
            monthly_remaining_percent=monthly,
        ),
        usage_sample_at=sampled_at,
        remaining_credits_primary=credits,
    )


def test_selects_greatest_limiting_remaining_quota_deterministically() -> None:
    selection = select_codex_launch_account(
        [
            _account("primary-rich-secondary-tight", primary=95, secondary=40),
            _account("balanced", primary=76, secondary=75),
            _account("primary-low", primary=60, secondary=99),
        ],
        now=NOW,
        max_sample_age_seconds=600,
    )

    assert selection.selected is not None
    assert selection.selected.account_id == "balanced"
    assert selection.selected.effective_remaining_percent == 75


def test_unknown_stale_exhausted_and_inactive_accounts_cannot_win() -> None:
    selection = select_codex_launch_account(
        [
            _account("unknown", primary=None),
            _account("stale", primary=100, sampled_at=NOW - timedelta(hours=1)),
            _account("exhausted", primary=90, secondary=0),
            _account("paused", primary=100, status="paused"),
            _account("usable", primary=30, secondary=25),
        ],
        now=NOW,
        max_sample_age_seconds=600,
    )

    assert selection.selected is not None
    assert selection.selected.account_id == "usable"
    reasons = {item.account_id: item.reason for item in selection.exclusions}
    assert reasons == {
        "exhausted": "quota_exhausted",
        "paused": "account_paused",
        "stale": "usage_sample_stale",
        "unknown": "usage_all_windows_unknown",
    }


def test_secondary_only_account_is_a_trustworthy_candidate() -> None:
    selection = select_codex_launch_account(
        [
            _account("weekly-only", primary=None, secondary=96),
            _account("primary", primary=81),
        ],
        now=NOW,
        max_sample_age_seconds=600,
    )

    assert selection.selected is not None
    assert selection.selected.account_id == "weekly-only"
    assert selection.selected.primary_remaining_percent is None
    assert selection.selected.effective_remaining_percent == 96


def test_account_without_any_known_usage_window_is_excluded() -> None:
    selection = select_codex_launch_account(
        [_account("unknown", primary=None, secondary=None, monthly=None)],
        now=NOW,
        max_sample_age_seconds=600,
    )

    assert selection.selected is None
    assert selection.exclusions[0].reason == "usage_all_windows_unknown"


def test_ties_use_capacity_then_stable_account_id() -> None:
    selection = select_codex_launch_account(
        [
            _account("z", primary=80, secondary=80, credits=400),
            _account("b", primary=80, secondary=80, credits=900),
            _account("a", primary=80, secondary=80, credits=900),
        ],
        now=NOW,
        max_sample_age_seconds=600,
    )

    assert [item.account_id for item in selection.candidates] == ["a", "b", "z"]


def test_free_plan_is_excluded_even_with_the_most_remaining_quota() -> None:
    selection = select_codex_launch_account(
        [
            _account("free", primary=100, secondary=100, plan_type="free"),
            _account("paid", primary=35, secondary=30, plan_type="plus"),
        ],
        now=NOW,
        max_sample_age_seconds=600,
    )

    assert selection.selected is not None
    assert selection.selected.account_id == "paid"
    assert [candidate.account_id for candidate in selection.candidates] == ["paid"]
    assert selection.exclusions[0].reason == "free_plan_not_routable"


def test_manual_free_only_pool_has_no_launch_candidate() -> None:
    selection = select_codex_launch_account(
        [_account("free", primary=100, plan_type="free")],
        now=NOW,
        max_sample_age_seconds=600,
    )

    assert selection.selected is None
    assert selection.exclusions[0].reason == "free_plan_not_routable"
