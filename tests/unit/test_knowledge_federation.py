from __future__ import annotations

import hashlib
import json
from pathlib import Path

import yaml

from app.modules.knowledge_federation import federate_shared_knowledge


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _fixture(tmp_path: Path) -> tuple[Path, Path, Path, Path]:
    canonical = tmp_path / ".codex"
    hermes = tmp_path / "hermes"
    opencode = tmp_path / ".config" / "opencode" / "opencode.jsonc"
    legacy = opencode.parent / "codex-memory-instructions.md"

    _write(canonical / "AGENTS.md", "# Global rules\n\nPreserve user data.\n")
    _write(canonical / "skills" / "alpha" / "SKILL.md", "# Alpha\n")
    _write(canonical / "memories" / "MEMORY.md", "# Registry\n")
    _write(canonical / "memories" / "memory_summary.md", "# Summary\n")
    _write(
        hermes / "config.yaml",
        "memory:\n  memory_enabled: true\n  user_profile_enabled: true\n"
        "skills:\n  external_dirs: []\n",
    )
    _write(
        hermes / "SOUL.md",
        "Existing persona.\n\n<!-- openhub:codex-agents:start -->\n"
        "# Global rules\n\nPreserve user data.\n"
        "<!-- openhub:codex-agents:end -->\n",
    )
    _write(
        hermes / "memories" / "MEMORY.md",
        "# Imported Codex durable memory summary (managed by OpenHUB)\n\n"
        "Stale copied summary.\n§\nHermes-only durable insight.\n",
    )
    _write(hermes / "memories" / "USER.md", "Hermes-only user preference.\n")

    copied_skill = hermes / "skills" / "codex-imports" / "alpha" / "SKILL.md"
    copied_memory = hermes / "memories" / "codex-imports" / "MEMORY.md"
    copied_agents = hermes / "imports" / "codex" / "AGENTS.md"
    _write(copied_skill, (canonical / "skills" / "alpha" / "SKILL.md").read_text())
    _write(copied_memory, (canonical / "memories" / "MEMORY.md").read_text())
    _write(copied_agents, (canonical / "AGENTS.md").read_text())
    manifest = {
        "version": 1,
        "source_root": str(canonical.resolve()),
        "target_root": str(hermes.resolve()),
        "agents": {"sha256": _sha256(copied_agents)},
        "skills": [
            {
                "relative_path": "alpha/SKILL.md",
                "sha256": _sha256(copied_skill),
                "mode": "copy",
            }
        ],
        "memories": [
            {
                "relative_path": "MEMORY.md",
                "sha256": _sha256(copied_memory),
                "mode": "copy",
            }
        ],
    }
    _write(
        hermes / "imports" / "codex" / "sync-manifest.json",
        json.dumps(manifest),
    )
    _write(
        legacy,
        "# Codex memory and history compatibility\n\n"
        "Use memories/extensions/ad_hoc/notes/ and codex_bridge_memory.\n",
    )
    _write(
        opencode,
        json.dumps(
            {
                "instructions": [legacy.as_posix()],
                "skills": {"paths": []},
                "references": {},
            }
        ),
    )
    return canonical, hermes, opencode, legacy


def test_federation_dry_run_is_read_only(tmp_path: Path) -> None:
    canonical, hermes, opencode, legacy = _fixture(tmp_path)

    report = federate_shared_knowledge(canonical, hermes, opencode)

    assert report.applied is False
    assert report.retired_files == 4
    assert legacy.exists()
    assert not (canonical / "federation").exists()
    assert not (hermes / "plugins" / "openhub-shared-knowledge").exists()


def test_federation_retires_verified_copies_and_reads_canonical_state(
    tmp_path: Path,
) -> None:
    canonical, hermes, opencode, legacy = _fixture(tmp_path)

    report = federate_shared_knowledge(canonical, hermes, opencode, apply=True)

    assert report.applied is True
    assert report.retired_files == 4
    assert report.retained_conflicts == ()
    assert (canonical / "skills" / "alpha" / "SKILL.md").read_text() == "# Alpha\n"
    assert not (hermes / "skills" / "codex-imports").exists()
    assert not (hermes / "memories" / "codex-imports").exists()
    assert not (hermes / "imports" / "codex").exists()

    protocol = canonical / "federation" / "runtime-memory-protocol.md"
    assert canonical.as_posix() in protocol.read_text(encoding="utf-8")
    plugin = hermes / "plugins" / "openhub-shared-knowledge" / "__init__.py"
    compile(plugin.read_text(encoding="utf-8"), str(plugin), "exec")
    assert "openhub-shared-knowledge-plugin:v1" in plugin.read_text(encoding="utf-8")

    config = yaml.safe_load((hermes / "config.yaml").read_text(encoding="utf-8"))
    assert config["memory"] == {
        "memory_enabled": False,
        "user_profile_enabled": False,
    }
    assert canonical.joinpath("skills").as_posix() in config["skills"]["external_dirs"]
    soul = (hermes / "SOUL.md").read_text(encoding="utf-8")
    assert "Existing persona." in soul
    assert "openhub:codex-agents" not in soul
    assert "openhub:shared-knowledge" in soul
    assert "Preserve user data." not in soul
    assert not (hermes / "memories" / "MEMORY.md").exists()
    assert not (hermes / "memories" / "USER.md").exists()

    note_contents = [
        Path(path).read_text(encoding="utf-8") for path in report.imported_memory_notes
    ]
    assert len(note_contents) == 2
    assert any("Hermes-only durable insight." in content for content in note_contents)
    assert any("Hermes-only user preference." in content for content in note_contents)
    assert all("Stale copied summary." not in content for content in note_contents)

    open_config = json.loads(opencode.read_text(encoding="utf-8"))
    assert legacy.as_posix() not in open_config["instructions"]
    assert canonical.joinpath("AGENTS.md").as_posix() in open_config["instructions"]
    assert canonical.joinpath("skills").as_posix() in open_config["skills"]["paths"]
    assert not legacy.exists()
    assert Path(report.hermes_backup_path or "").joinpath("SOUL.md").exists()
    assert Path(report.opencode_backup_path or "").joinpath("opencode.jsonc").exists()
    assert Path(report.federation_manifest_path).exists()


def test_federation_preserves_changed_copy_and_transitional_manifest(
    tmp_path: Path,
) -> None:
    canonical, hermes, opencode, _legacy = _fixture(tmp_path)
    changed = hermes / "skills" / "codex-imports" / "alpha" / "SKILL.md"
    changed.write_text("User changed this copy.\n", encoding="utf-8")

    report = federate_shared_knowledge(canonical, hermes, opencode, apply=True)

    assert changed.read_text(encoding="utf-8") == "User changed this copy.\n"
    assert (hermes / "imports" / "codex" / "sync-manifest.json").exists()
    assert any(
        item.path == str(changed) and item.reason == "content_or_ownership_changed"
        for item in report.retained_conflicts
    )


def test_federation_preserves_unowned_opencode_instruction(tmp_path: Path) -> None:
    canonical, hermes, opencode, legacy = _fixture(tmp_path)
    legacy.write_text("# User-owned OpenCode instructions\n", encoding="utf-8")

    report = federate_shared_knowledge(canonical, hermes, opencode, apply=True)

    config = json.loads(opencode.read_text(encoding="utf-8"))
    assert legacy.exists()
    assert legacy.as_posix() in config["instructions"]
    assert any(
        item.path == str(legacy) and item.reason == "unowned_legacy_instruction_preserved"
        for item in report.retained_conflicts
    )
