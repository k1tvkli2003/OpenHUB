from __future__ import annotations

from typing import AbstractSet, Final

ACCOUNT_PLAN_TYPES: Final[set[str]] = {
    "free",
    "plus",
    "pro",
    "prolite",
    "team",
    "business",
    "enterprise",
    "edu",
}

RATE_LIMIT_PLAN_TYPES: Final[set[str]] = {
    *ACCOUNT_PLAN_TYPES,
    "guest",
    "go",
    "free_workspace",
    "education",
    "quorum",
    "k12",
}

ACCOUNT_PLAN_EQUIVALENTS: Final[dict[str, frozenset[str]]] = {
    "prolite": frozenset({"pro"}),
}

# These labels all describe the non-paid account family for routing purposes.
# Keep this separate from normalization: unknown/unreported plans must retain
# their existing compatibility behavior, while an explicit Free-family value
# is a hard product-level routing exclusion.
FREE_ROUTING_BLOCKED_PLAN_TYPES: Final[frozenset[str]] = frozenset(
    {"free", "guest", "go", "free_workspace", "quorum"}
)


def _clean_plan_type(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned or None


def normalize_account_plan_type(value: str | None) -> str | None:
    cleaned = _clean_plan_type(value)
    if not cleaned:
        return None
    normalized = cleaned.lower()
    return normalized if normalized in ACCOUNT_PLAN_TYPES else None


def canonicalize_account_plan_type(value: str | None) -> str | None:
    cleaned = _clean_plan_type(value)
    if not cleaned:
        return None
    normalized = cleaned.lower()
    if normalized in ACCOUNT_PLAN_TYPES:
        return normalized
    return cleaned


def coerce_account_plan_type(value: str | None, default: str) -> str:
    cleaned = _clean_plan_type(value)
    if cleaned is None:
        return default
    canonical = canonicalize_account_plan_type(cleaned)
    return canonical if canonical is not None else default


def is_free_account_plan(value: str | None) -> bool:
    cleaned = _clean_plan_type(value)
    return cleaned is not None and cleaned.lower() in FREE_ROUTING_BLOCKED_PLAN_TYPES


def normalize_rate_limit_plan_type(value: str | None) -> str | None:
    cleaned = _clean_plan_type(value)
    if not cleaned:
        return None
    normalized = cleaned.lower()
    return normalized if normalized in RATE_LIMIT_PLAN_TYPES else None


def account_plan_matches_allowed(value: str | None, allowed_plans: AbstractSet[str]) -> bool:
    cleaned = _clean_plan_type(value)
    if cleaned is None:
        return False
    normalized_allowed = {plan.lower() for plan in allowed_plans}
    normalized = normalize_account_plan_type(cleaned)
    candidate = normalized or cleaned.lower()
    if candidate in normalized_allowed:
        return True
    if normalized is None:
        return False
    return bool(ACCOUNT_PLAN_EQUIVALENTS.get(normalized, frozenset()) & normalized_allowed)
