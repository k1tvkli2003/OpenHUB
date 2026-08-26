from __future__ import annotations

import hashlib
import hmac
import json
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

from app.core.config.settings import get_settings
from app.core.utils.paths import expand_user_path
from app.modules.storage_cleanup.schemas import CleanupCategory


class StorageCleanupPreviewChangedError(ValueError):
    """Raised when files changed between preview and confirmed cleanup."""


@dataclass(frozen=True)
class CleanupCandidate:
    category: CleanupCategory
    path: Path
    relative_path: str
    size_bytes: int
    modified_at: datetime
    modified_ns: int


@dataclass(frozen=True)
class CleanupPreview:
    older_than_days: int
    cutoff: datetime
    candidates: tuple[CleanupCandidate, ...]
    confirmation_token: str

    @property
    def total_bytes(self) -> int:
        return sum(candidate.size_bytes for candidate in self.candidates)


@dataclass(frozen=True)
class CleanupResult:
    deleted_files: int
    deleted_bytes: int
    skipped_files: int


def preview_cleanup(
    *, categories: list[CleanupCategory], older_than_days: int, now: datetime | None = None
) -> CleanupPreview:
    resolved_now = (now or datetime.now(UTC)).astimezone(UTC)
    cutoff = resolved_now - timedelta(days=older_than_days)
    candidates = tuple(_collect_candidates(categories, cutoff=cutoff))
    return CleanupPreview(
        older_than_days=older_than_days,
        cutoff=cutoff,
        candidates=candidates,
        confirmation_token=_confirmation_token(
            categories=categories,
            older_than_days=older_than_days,
            candidates=candidates,
        ),
    )


def apply_cleanup(
    *,
    categories: list[CleanupCategory],
    older_than_days: int,
    confirmation_token: str,
    now: datetime | None = None,
) -> CleanupResult:
    preview = preview_cleanup(categories=categories, older_than_days=older_than_days, now=now)
    if not hmac.compare_digest(preview.confirmation_token, confirmation_token):
        raise StorageCleanupPreviewChangedError(
            "Cleanup preview changed. Review the current file list and confirm again."
        )

    deleted_files = 0
    deleted_bytes = 0
    skipped_files = 0
    for candidate in preview.candidates:
        if not _candidate_is_still_safe(candidate, cutoff=preview.cutoff):
            skipped_files += 1
            continue
        try:
            candidate.path.unlink()
        except FileNotFoundError:
            skipped_files += 1
        except OSError:
            skipped_files += 1
        else:
            deleted_files += 1
            deleted_bytes += candidate.size_bytes
    return CleanupResult(
        deleted_files=deleted_files,
        deleted_bytes=deleted_bytes,
        skipped_files=skipped_files,
    )


def _collect_candidates(categories: list[CleanupCategory], *, cutoff: datetime) -> list[CleanupCandidate]:
    settings = get_settings()
    data_dir = Path(settings.data_dir).expanduser().resolve(strict=False)
    roots: dict[CleanupCategory, tuple[Path, tuple[str, ...], bool]] = {
        "conversation_archives": (
            expand_user_path(settings.conversation_archive_dir).resolve(strict=False),
            (".jsonl", ".jsonl.gz"),
            False,
        ),
        "debug_dumps": (
            (data_dir / "debug" / "response-create-dumps").resolve(strict=False),
            (".response-create.json.gz", ".meta.json"),
            False,
        ),
        "temporary_files": (
            (data_dir / ".tmp").resolve(strict=False),
            (".tmp", ".sqlite", ".sqlite-wal", ".sqlite-shm"),
            True,
        ),
    }

    candidates: list[CleanupCandidate] = []
    for category in dict.fromkeys(categories):
        root, suffixes, recursive = roots[category]
        if not root.exists() or not root.is_dir() or root.is_symlink():
            continue
        iterator = root.rglob("*") if recursive else root.iterdir()
        for path in iterator:
            candidate = _safe_candidate(
                category=category,
                root=root,
                path=path,
                suffixes=suffixes,
                cutoff=cutoff,
            )
            if candidate is not None:
                candidates.append(candidate)
    candidates.sort(key=lambda item: (item.category, item.relative_path))
    return candidates


def _safe_candidate(
    *,
    category: CleanupCategory,
    root: Path,
    path: Path,
    suffixes: tuple[str, ...],
    cutoff: datetime,
) -> CleanupCandidate | None:
    if path.is_symlink() or not path.is_file() or not path.name.endswith(suffixes):
        return None
    resolved = path.resolve(strict=True)
    try:
        relative = resolved.relative_to(root)
    except ValueError:
        return None
    stat = resolved.stat()
    modified_at = datetime.fromtimestamp(stat.st_mtime, tz=UTC)
    if modified_at >= cutoff:
        return None
    return CleanupCandidate(
        category=category,
        path=resolved,
        relative_path=f"{category}/{relative.as_posix()}",
        size_bytes=stat.st_size,
        modified_at=modified_at,
        modified_ns=stat.st_mtime_ns,
    )


def _candidate_is_still_safe(candidate: CleanupCandidate, *, cutoff: datetime) -> bool:
    try:
        if candidate.path.is_symlink() or not candidate.path.is_file():
            return False
        stat = candidate.path.stat()
    except OSError:
        return False
    return (
        stat.st_size == candidate.size_bytes
        and stat.st_mtime_ns == candidate.modified_ns
        and datetime.fromtimestamp(stat.st_mtime, tz=UTC) < cutoff
    )


def _confirmation_token(
    *,
    categories: list[CleanupCategory],
    older_than_days: int,
    candidates: tuple[CleanupCandidate, ...],
) -> str:
    payload = {
        "categories": sorted(set(categories)),
        "older_than_days": older_than_days,
        "files": [[item.category, item.relative_path, item.size_bytes, item.modified_ns] for item in candidates],
    }
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()
