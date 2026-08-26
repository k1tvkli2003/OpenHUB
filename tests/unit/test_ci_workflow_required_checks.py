from __future__ import annotations

import re
from pathlib import Path

import yaml

CI_WORKFLOW = Path(__file__).parents[2] / ".github" / "workflows" / "ci.yml"
RELEASE_WORKFLOW = Path(__file__).parents[2] / ".github" / "workflows" / "release.yml"
_PINNED_ACTION = re.compile(r"^[^\s]+@[0-9a-f]{40}$")


def _workflow(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def _uses(workflow: dict) -> list[str]:
    result: list[str] = []
    for job in workflow["jobs"].values():
        for step in job.get("steps", []):
            if "uses" in step:
                result.append(step["uses"])
    return result


def test_ci_runs_each_shipped_product_surface() -> None:
    workflow = _workflow(CI_WORKFLOW)

    assert set(workflow["jobs"]) == {
        "backend",
        "dashboard",
        "native-windows",
        "helm-contracts",
        "helm-smoke",
        "contracts",
    }
    text = CI_WORKFLOW.read_text(encoding="utf-8")
    for command in (
        "uv run ruff check app tests scripts",
        "uv run pytest tests/unit -q",
        "bun run lint",
        "bun run typecheck",
        "bun run test",
        "bun run build",
        "flutter analyze",
        "flutter test",
        "flutter build windows --release --no-pub",
        "make helm-check",
        "make helm-smoke-kind",
        "openspec validate --specs --strict",
    ):
        assert command in text


def test_workflows_pin_every_external_action_to_a_full_commit() -> None:
    uses = _uses(_workflow(CI_WORKFLOW)) + _uses(_workflow(RELEASE_WORKFLOW))

    assert uses
    assert all(_PINNED_ACTION.fullmatch(value) for value in uses)


def test_release_is_serialized_without_cancelling_and_has_scoped_permissions() -> None:
    workflow = _workflow(RELEASE_WORKFLOW)

    assert workflow["concurrency"]["cancel-in-progress"] is False
    assert workflow["permissions"] == {"contents": "read"}
    assert workflow["jobs"]["publish"]["permissions"] == {
        "contents": "write",
        "id-token": "write",
        "attestations": "write",
    }


def test_release_contains_integrity_and_provenance_outputs() -> None:
    text = RELEASE_WORKFLOW.read_text(encoding="utf-8")

    assert "SHA256SUMS.txt" in text
    assert ".sbom.spdx.json" in text
    assert "actions/attest-build-provenance@" in text
    assert "cancel-in-progress: false" in text
