from __future__ import annotations

import hashlib
import json
import os
import shutil
import tempfile
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path

import yaml

_FEDERATION_VERSION = 1
_OLD_SOUL_START = "<!-- openhub:codex-agents:start -->"
_OLD_SOUL_END = "<!-- openhub:codex-agents:end -->"
_SOUL_START = "<!-- openhub:shared-knowledge:start -->"
_SOUL_END = "<!-- openhub:shared-knowledge:end -->"
_OLD_MEMORY_HEADING = "# Imported Codex durable memory summary (managed by OpenHUB)"
_MEMORY_DELIMITER = "\n§\n"
_PROTOCOL_MARKER = "<!-- openhub:canonical-runtime-memory-protocol:v1 -->"
_PLUGIN_MARKER = "# openhub-shared-knowledge-plugin:v1"
_PLUGIN_NAME = "openhub-shared-knowledge"

_HERMES_PLUGIN = f'''"""Load OpenHUB's canonical Codex instructions and memory without copies."""

{_PLUGIN_MARKER}
import os
from pathlib import Path


def _canonical_root():
    configured = os.environ.get("CODEX_HOME", "").strip()
    return Path(configured) if configured else Path.home() / ".codex"


def _read(relative, limit=24000):
    try:
        path = (_canonical_root() / relative).resolve()
        root = _canonical_root().resolve()
        if not path.is_relative_to(root) or not path.is_file():
            return ""
        return path.read_text(encoding="utf-8")[:limit]
    except (OSError, UnicodeError):
        return ""


def _first_turn_slice(relative, start, stop, label):
    def callback(*, is_first_turn=False, **kwargs):
        if not is_first_turn:
            return None
        text = _read(relative)
        chunk = text[start:stop]
        if not chunk:
            return None
        return {{"context": f"<openhub-canonical-{{label}}>\\n{{chunk}}\\n</openhub-canonical-{{label}}>"}}
    return callback


def _pointer(session_info):
    root = _canonical_root()
    return (
        "OpenHUB shared-knowledge federation is active. The authoritative global "
        f"instructions are {{root / 'AGENTS.md'}} and memory is under "
        f"{{root / 'memories'}}. Read them live; do not create Hermes copies."
    )


def register(ctx):
    ctx.register_system_prompt_section(
        "openhub.shared-knowledge",
        _pointer,
        position="after_memory",
        max_chars=1200,
    )
    for index, (start, stop) in enumerate(((0, 7000), (7000, 14000), (14000, 21000))):
        ctx.register_hook(
            "pre_llm_call",
            _first_turn_slice("AGENTS.md", start, stop, f"instructions-{{index + 1}}"),
        )
    ctx.register_hook(
        "pre_llm_call",
        _first_turn_slice("memories/memory_summary.md", 0, 9000, "memory-summary"),
    )
    ctx.register_hook(
        "pre_llm_call",
        _first_turn_slice("federation/runtime-memory-protocol.md", 0, 9000, "memory-protocol"),
    )
'''

_HERMES_PLUGIN_MANIFEST = """name: openhub-shared-knowledge
version: 1.0.0
description: Load canonical OpenHUB instructions and memory directly from CODEX_HOME.
author: OpenHUB
provides_hooks:
  - pre_llm_call
"""


class KnowledgeFederationError(RuntimeError):
    """Raised when shared knowledge cannot be federated without data loss."""


@dataclass(frozen=True, slots=True)
class FederationConflict:
    path: str
    reason: str


@dataclass(frozen=True, slots=True)
class KnowledgeFederationReport:
    canonical_root: str
    hermes_root: str
    opencode_config: str
    applied: bool
    timestamp: str
    retired_files: int
    retained_conflicts: tuple[FederationConflict, ...]
    imported_memory_notes: tuple[str, ...]
    hermes_plugin_path: str
    federation_manifest_path: str
    hermes_backup_path: str | None
    opencode_backup_path: str | None


def federate_shared_knowledge(
    canonical_root: Path,
    hermes_root: Path,
    opencode_config: Path,
    *,
    apply: bool = False,
) -> KnowledgeFederationReport:
    canonical = canonical_root.expanduser().resolve()
    hermes = hermes_root.expanduser().resolve()
    opencode = opencode_config.expanduser().resolve()
    _validate_roots(canonical, hermes, opencode)
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    plugin_path = hermes / "plugins" / _PLUGIN_NAME
    federation_manifest = hermes / "imports" / "openhub" / "federation-manifest.json"
    hermes_backup = hermes / "backups" / "openhub-knowledge-federation" / stamp
    opencode_backup = opencode.parent / "backups" / "openhub-knowledge-federation" / stamp

    retirement = _plan_retirement(canonical, hermes)
    conflicts = list(retirement.conflicts)
    if not apply:
        return KnowledgeFederationReport(
            canonical_root=str(canonical),
            hermes_root=str(hermes),
            opencode_config=str(opencode),
            applied=False,
            timestamp=stamp,
            retired_files=retirement.safe_files,
            retained_conflicts=tuple(conflicts),
            imported_memory_notes=(),
            hermes_plugin_path=str(plugin_path),
            federation_manifest_path=str(federation_manifest),
            hermes_backup_path=None,
            opencode_backup_path=None,
        )

    hermes_backup.mkdir(parents=True, exist_ok=False)
    opencode_backup.mkdir(parents=True, exist_ok=False)
    for path in (
        hermes / "config.yaml",
        hermes / "SOUL.md",
        hermes / "memories" / "MEMORY.md",
        hermes / "memories" / "USER.md",
    ):
        _backup_owned_file(path, hermes, hermes_backup)
    _backup_owned_file(opencode, opencode.parent, opencode_backup)
    legacy_opencode_instruction = opencode.parent / "codex-memory-instructions.md"
    legacy_conflict = _legacy_instruction_conflict(legacy_opencode_instruction)
    if legacy_conflict is not None:
        conflicts.append(legacy_conflict)
    _backup_owned_file(legacy_opencode_instruction, opencode.parent, opencode_backup)

    protocol_path = canonical / "federation" / "runtime-memory-protocol.md"
    _ensure_managed_file(protocol_path, _protocol_content(canonical), _PROTOCOL_MARKER)
    _configure_hermes(hermes, canonical)
    _install_hermes_plugin(plugin_path)
    applied_legacy_conflict = _configure_opencode(
        opencode,
        canonical,
        protocol_path,
        legacy_opencode_instruction,
    )
    if applied_legacy_conflict is not None and applied_legacy_conflict not in conflicts:
        conflicts.append(applied_legacy_conflict)
    imported_notes = _retire_hermes_active_memory(hermes, canonical, stamp)
    retired, retirement_conflicts = _retire_verified_files(retirement)
    conflicts.extend(item for item in retirement_conflicts if item not in conflicts)

    manifest_payload = {
        "version": _FEDERATION_VERSION,
        "created_at": stamp,
        "canonical_root": str(canonical),
        "hermes_root": str(hermes),
        "opencode_config": str(opencode),
        "hermes_plugin": str(plugin_path),
        "protocol": str(protocol_path),
        "retired_files": retired,
        "retained_conflicts": [asdict(item) for item in conflicts],
        "imported_memory_notes": list(imported_notes),
        "hermes_backup": str(hermes_backup),
        "opencode_backup": str(opencode_backup),
    }
    _atomic_write_text(
        federation_manifest,
        json.dumps(manifest_payload, ensure_ascii=False, indent=2) + "\n",
    )
    return KnowledgeFederationReport(
        canonical_root=str(canonical),
        hermes_root=str(hermes),
        opencode_config=str(opencode),
        applied=True,
        timestamp=stamp,
        retired_files=retired,
        retained_conflicts=tuple(conflicts),
        imported_memory_notes=imported_notes,
        hermes_plugin_path=str(plugin_path),
        federation_manifest_path=str(federation_manifest),
        hermes_backup_path=str(hermes_backup),
        opencode_backup_path=str(opencode_backup),
    )


@dataclass(frozen=True, slots=True)
class _RetirementEntry:
    target: Path
    source: Path
    sha256: str
    mode: str


@dataclass(frozen=True, slots=True)
class _RetirementPlan:
    files: tuple[_RetirementEntry, ...]
    empty_roots: tuple[Path, ...]
    manifest_path: Path | None
    manifest_sha256: str | None
    safe_files: int
    conflicts: tuple[FederationConflict, ...]


def _validate_roots(canonical: Path, hermes: Path, opencode: Path) -> None:
    for required in (
        canonical / "AGENTS.md",
        canonical / "skills",
        canonical / "memories" / "MEMORY.md",
        canonical / "memories" / "memory_summary.md",
        hermes / "config.yaml",
        opencode,
    ):
        if not required.exists():
            raise KnowledgeFederationError(f"Required federation path is missing: {required}")
    if hermes == canonical or hermes.is_relative_to(canonical) or canonical.is_relative_to(hermes):
        raise KnowledgeFederationError("Canonical and Hermes roots must remain separate owners.")


def _plan_retirement(canonical: Path, hermes: Path) -> _RetirementPlan:
    old_manifest = hermes / "imports" / "codex" / "sync-manifest.json"
    if not old_manifest.is_file():
        return _RetirementPlan((), (), None, None, 0, ())
    try:
        payload = json.loads(old_manifest.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise KnowledgeFederationError("The transitional copy manifest is unreadable.") from exc
    if Path(str(payload.get("source_root", ""))).resolve() != canonical:
        raise KnowledgeFederationError("The transitional manifest belongs to a different canonical root.")
    if Path(str(payload.get("target_root", ""))).resolve() != hermes:
        raise KnowledgeFederationError("The transitional manifest belongs to a different Hermes root.")

    safe: list[_RetirementEntry] = []
    conflicts: list[FederationConflict] = []
    roots: list[Path] = []
    categories = (
        ("skills", canonical / "skills", hermes / "skills" / "codex-imports"),
        ("memories", canonical / "memories", hermes / "memories" / "codex-imports"),
    )
    for key, source_root, target_root in categories:
        roots.append(target_root)
        entries = payload.get(key, [])
        if not isinstance(entries, list):
            raise KnowledgeFederationError(f"Invalid transitional manifest section: {key}")
        for item in entries:
            if not isinstance(item, dict):
                continue
            relative = _safe_relative_path(item.get("relative_path"))
            target = target_root / relative
            source = source_root / relative
            if not target.exists():
                continue
            if not target.is_file():
                conflicts.append(FederationConflict(str(target), "not_a_regular_file"))
                continue
            recorded = str(item.get("sha256", ""))
            mode = str(item.get("mode", ""))
            if _matches_manifest_file(source, target, recorded, mode):
                safe.append(_RetirementEntry(target, source, recorded, mode))
            else:
                conflicts.append(FederationConflict(str(target), "content_or_ownership_changed"))

    agents_target = hermes / "imports" / "codex" / "AGENTS.md"
    if agents_target.exists():
        agents = payload.get("agents", {})
        recorded = str(agents.get("sha256", "")) if isinstance(agents, dict) else ""
        if agents_target.is_file() and _sha256(agents_target) == recorded:
            safe.append(
                _RetirementEntry(agents_target, canonical / "AGENTS.md", recorded, "copy")
            )
        else:
            conflicts.append(FederationConflict(str(agents_target), "content_or_ownership_changed"))
    roots.append(old_manifest.parent)
    manifest_sha = _sha256(old_manifest)
    safe_files = len(safe) + (0 if conflicts else 1)
    return _RetirementPlan(
        tuple(safe),
        tuple(roots),
        old_manifest,
        manifest_sha,
        safe_files,
        tuple(conflicts),
    )


def _matches_manifest_file(source: Path, target: Path, recorded: str, mode: str) -> bool:
    if len(recorded) != 64:
        return False
    if mode == "hardlink" and source.is_file():
        try:
            if os.path.samefile(source, target):
                return True
        except OSError:
            pass
    try:
        return _sha256(target) == recorded
    except OSError:
        return False


def _retire_verified_files(
    plan: _RetirementPlan,
) -> tuple[int, tuple[FederationConflict, ...]]:
    retired = 0
    conflicts: list[FederationConflict] = []
    for entry in plan.files:
        if not entry.target.exists():
            continue
        if not entry.target.is_file() or not _matches_manifest_file(
            entry.source,
            entry.target,
            entry.sha256,
            entry.mode,
        ):
            conflicts.append(
                FederationConflict(str(entry.target), "changed_after_retirement_plan")
            )
            continue
        entry.target.unlink()
        retired += 1
    if (
        plan.manifest_path is not None
        and plan.manifest_sha256 is not None
        and not plan.conflicts
        and not conflicts
        and plan.manifest_path.is_file()
    ):
        if _sha256(plan.manifest_path) == plan.manifest_sha256:
            plan.manifest_path.unlink()
            retired += 1
        else:
            conflicts.append(
                FederationConflict(str(plan.manifest_path), "changed_after_retirement_plan")
            )
    for root in plan.empty_roots:
        _remove_empty_directories(root)
    return retired, tuple(conflicts)


def _remove_empty_directories(root: Path) -> None:
    if not root.is_dir():
        return
    directories = sorted(
        (path for path in root.rglob("*") if path.is_dir()),
        key=lambda path: len(path.parts),
        reverse=True,
    )
    for path in (*directories, root):
        try:
            path.rmdir()
        except OSError:
            pass


def _configure_hermes(hermes: Path, canonical: Path) -> None:
    config_path = hermes / "config.yaml"
    try:
        config = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    except (OSError, UnicodeError, yaml.YAMLError) as exc:
        raise KnowledgeFederationError("Hermes config.yaml is unreadable.") from exc
    if not isinstance(config, dict):
        raise KnowledgeFederationError("Hermes config.yaml must contain a mapping.")
    memory = config.setdefault("memory", {})
    skills = config.setdefault("skills", {})
    if not isinstance(memory, dict) or not isinstance(skills, dict):
        raise KnowledgeFederationError("Hermes memory/skills configuration is invalid.")
    memory["memory_enabled"] = False
    memory["user_profile_enabled"] = False
    external = skills.setdefault("external_dirs", [])
    if not isinstance(external, list):
        raise KnowledgeFederationError("Hermes skills.external_dirs must be a list.")
    for required in (
        canonical / "skills",
        canonical / "plugins" / "cache",
        canonical.parent / ".agents" / "skills",
    ):
        if not any(_same_config_path(value, required) for value in external):
            external.append(required.as_posix())
    _atomic_write_text(
        config_path,
        yaml.safe_dump(config, allow_unicode=True, sort_keys=False, width=120),
    )

    soul_path = hermes / "SOUL.md"
    soul = soul_path.read_text(encoding="utf-8") if soul_path.exists() else ""
    soul = _remove_managed_block(soul, _OLD_SOUL_START, _OLD_SOUL_END)
    pointer = (
        f"{_SOUL_START}\n"
        "OpenHUB loads the exact global instructions and memory from the live canonical "
        f"repository at `{canonical}` through the `{_PLUGIN_NAME}` plugin. "
        "Do not create local knowledge copies.\n"
        f"{_SOUL_END}"
    )
    soul = _replace_managed_block(soul, pointer, _SOUL_START, _SOUL_END)
    _atomic_write_text(soul_path, soul)


def _configure_opencode(
    config_path: Path,
    canonical: Path,
    protocol_path: Path,
    legacy_instruction: Path,
) -> FederationConflict | None:
    try:
        config = json.loads(_strip_jsonc_comments(config_path.read_text(encoding="utf-8")))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise KnowledgeFederationError("OpenCode opencode.jsonc is unreadable.") from exc
    if not isinstance(config, dict):
        raise KnowledgeFederationError("OpenCode config must contain an object.")
    instructions = config.setdefault("instructions", [])
    skills = config.setdefault("skills", {})
    references = config.setdefault("references", {})
    if not isinstance(instructions, list) or not isinstance(skills, dict) or not isinstance(references, dict):
        raise KnowledgeFederationError("OpenCode knowledge configuration is invalid.")
    legacy_owned = _is_owned_legacy_instruction(legacy_instruction)
    if legacy_owned or not legacy_instruction.exists():
        instructions[:] = [
            value
            for value in instructions
            if not _same_config_path(value, legacy_instruction)
        ]
    for required in (
        canonical / "AGENTS.md",
        protocol_path,
        canonical / "memories" / "memory_summary.md",
    ):
        if not any(_same_config_path(value, required) for value in instructions):
            instructions.append(required.as_posix())
    paths = skills.setdefault("paths", [])
    if not isinstance(paths, list):
        raise KnowledgeFederationError("OpenCode skills.paths must be a list.")
    for required in (
        canonical / "skills",
        canonical / "plugins" / "cache",
        canonical.parent / ".agents" / "skills",
        canonical / "memories" / "skills",
    ):
        if not any(_same_config_path(value, required) for value in paths):
            paths.append(required.as_posix())
    references["openhub-memory"] = {
        "path": (canonical / "memories").as_posix(),
        "description": "Live canonical OpenHUB memory and rollout evidence",
        "hidden": True,
    }
    _atomic_write_text(config_path, json.dumps(config, ensure_ascii=False, indent=2) + "\n")
    if legacy_owned:
        legacy_instruction.unlink()
        return None
    return _legacy_instruction_conflict(legacy_instruction)


def _legacy_instruction_conflict(path: Path) -> FederationConflict | None:
    if not path.exists() or _is_owned_legacy_instruction(path):
        return None
    return FederationConflict(str(path), "unowned_legacy_instruction_preserved")


def _is_owned_legacy_instruction(path: Path) -> bool:
    if not path.is_file():
        return False
    content = path.read_text(encoding="utf-8", errors="ignore")
    return (
        content.startswith("# Codex memory and history compatibility\n")
        and "memories/extensions/ad_hoc/notes/" in content
        and "codex_bridge_memory" in content
    )


def _protocol_content(canonical: Path) -> str:
    root = canonical.as_posix()
    return f"""{_PROTOCOL_MARKER}
# Shared runtime memory protocol

`{root}` is the live canonical repository for Codex, Hermes, and OpenCode
skills, memories, and global agent instructions. Read these files directly;
never create a client-specific mirror:

- `AGENTS.md` for global instructions
- `memories/memory_summary.md` for the compact index
- `memories/MEMORY.md` for the searchable registry
- `memories/rollout_summaries/` for exact historical evidence
- `skills/` for executable personal skills

Use memory when prior work, paths, conventions, or decisions could matter.
Search narrowly and verify drift-prone facts live. Native chat/session databases
remain owned by their runtimes and are not copied into this repository.

Only when the user explicitly requests a durable memory update, add one small
timestamped note under `memories/extensions/ad_hoc/notes/`; never rewrite the
generated memory registry directly.
"""


def _install_hermes_plugin(plugin_path: Path) -> None:
    plugin_path.mkdir(parents=True, exist_ok=True)
    init_path = plugin_path / "__init__.py"
    manifest_path = plugin_path / "plugin.yaml"
    if init_path.exists() and _PLUGIN_MARKER not in init_path.read_text(
        encoding="utf-8", errors="ignore"
    ):
        raise KnowledgeFederationError(f"Refusing to overwrite an unowned Hermes plugin: {init_path}")
    _atomic_write_text(init_path, _HERMES_PLUGIN)
    _atomic_write_text(manifest_path, _HERMES_PLUGIN_MANIFEST)


def _retire_hermes_active_memory(hermes: Path, canonical: Path, stamp: str) -> tuple[str, ...]:
    notes: list[str] = []
    memory_dir = hermes / "memories"
    for name, slug in (("MEMORY.md", "hermes-memory-import"), ("USER.md", "hermes-user-import")):
        source = memory_dir / name
        if not source.is_file():
            continue
        content = source.read_text(encoding="utf-8")
        if name == "MEMORY.md":
            entries = [entry.strip() for entry in content.split(_MEMORY_DELIMITER) if entry.strip()]
            entries = [entry for entry in entries if not entry.startswith(_OLD_MEMORY_HEADING)]
            content = _MEMORY_DELIMITER.join(entries).strip()
        if content:
            note = canonical / "memories" / "extensions" / "ad_hoc" / "notes" / f"{stamp}-{slug}.md"
            _atomic_write_text(
                note,
                f"# Imported from inactive Hermes {name}\n\n{content.rstrip()}\n",
            )
            notes.append(str(note))
        source.unlink()
    return tuple(notes)


def _ensure_managed_file(path: Path, content: str, marker: str) -> None:
    if path.exists():
        existing = path.read_text(encoding="utf-8", errors="ignore")
        if marker not in existing and existing != content:
            raise KnowledgeFederationError(f"Refusing to overwrite unowned canonical file: {path}")
    _atomic_write_text(path, content)


def _replace_managed_block(existing: str, block: str, start: str, end: str) -> str:
    cleaned = _remove_managed_block(existing, start, end).rstrip()
    return f"{cleaned}\n\n{block}\n" if cleaned else f"{block}\n"


def _remove_managed_block(existing: str, start: str, end: str) -> str:
    begin = existing.find(start)
    finish = existing.find(end)
    if begin < 0 or finish < begin:
        return existing
    finish += len(end)
    return f"{existing[:begin].rstrip()}\n{existing[finish:].lstrip()}".strip() + "\n"


def _strip_jsonc_comments(content: str) -> str:
    output: list[str] = []
    index = 0
    in_string = False
    escaped = False
    while index < len(content):
        char = content[index]
        next_char = content[index + 1] if index + 1 < len(content) else ""
        if in_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            output.append(char)
            index += 1
            continue
        if char == "/" and next_char == "/":
            index += 2
            while index < len(content) and content[index] not in "\r\n":
                index += 1
            continue
        if char == "/" and next_char == "*":
            index += 2
            while index + 1 < len(content) and content[index : index + 2] != "*/":
                index += 1
            index += 2
            continue
        output.append(char)
        index += 1
    return "".join(output)


def _safe_relative_path(value: object) -> Path:
    path = Path(str(value or ""))
    if not path.parts or path.is_absolute() or ".." in path.parts:
        raise KnowledgeFederationError(f"Unsafe path in transitional manifest: {value}")
    return path


def _same_config_path(value: object, expected: Path) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    expanded = os.path.expandvars(os.path.expanduser(value.strip()))
    try:
        return Path(expanded).resolve() == expected.resolve()
    except OSError:
        return False


def _backup_owned_file(path: Path, owner_root: Path, backup_root: Path) -> None:
    if not path.is_file():
        return
    try:
        relative = path.relative_to(owner_root)
    except ValueError as exc:
        raise KnowledgeFederationError(f"Backup path escaped its owner root: {path}") from exc
    destination = backup_root / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, destination)


def _atomic_write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, raw_temp = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temp = Path(raw_temp)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


__all__ = [
    "FederationConflict",
    "KnowledgeFederationError",
    "KnowledgeFederationReport",
    "federate_shared_knowledge",
]
