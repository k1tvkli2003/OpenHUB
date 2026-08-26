from __future__ import annotations

import re

_ACCOUNT_NAME_SEPARATORS = re.compile(r"[\W_]+", flags=re.UNICODE)
_TRAILING_DIGITS = re.compile(r"\d+$")
_FALLBACK_ACCOUNT_NAME = "Account"


def account_display_name(*, email: str | None, alias: str | None = None) -> str:
    """Return the operator alias or a compact display-only name from email."""
    if alias is not None and alias.strip():
        return alias.strip()

    local_part = (email or "").strip().split("@", 1)[0]
    normalized = _ACCOUNT_NAME_SEPARATORS.sub(" ", local_part).strip()
    normalized = _TRAILING_DIGITS.sub("", normalized).strip()
    if not normalized:
        return _FALLBACK_ACCOUNT_NAME
    return f"{normalized[:1].upper()}{normalized[1:]}"
