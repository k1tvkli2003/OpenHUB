from __future__ import annotations

import os
from pathlib import Path


def expand_user_path(path: str | Path) -> Path:
    """Expand a configured ``~`` path consistently on every supported OS."""
    candidate = Path(path)
    if candidate.parts and candidate.parts[0] == "~":
        configured_home = os.environ.get("HOME")
        if configured_home:
            return Path(configured_home).joinpath(*candidate.parts[1:])
    return candidate.expanduser()
