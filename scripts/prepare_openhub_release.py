#!/usr/bin/env python3
"""Apply one release version across the OpenHUB release contract."""

from __future__ import annotations

import argparse
from pathlib import Path

from scripts.release_versions import assert_project_versions, update_project_versions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    update_project_versions(root, args.version)
    assert_project_versions(root, args.version)
    print(f"OpenHUB release contract set to {args.version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
