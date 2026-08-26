from __future__ import annotations

from pathlib import Path

import pytest

pytestmark = pytest.mark.unit

REPO_ROOT = Path(__file__).resolve().parents[2]


def test_native_backend_uses_its_own_environment_without_web_ui_duplication() -> None:
    spec = (REPO_ROOT / "scripts" / "native_windows" / "openhub_backend.spec").read_text(encoding="utf-8")

    assert '(str(project_root / "app" / "static"), "app/static")' not in spec
    assert "venv_site_packages" not in spec
