from __future__ import annotations

import os
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest

from app.modules.storage_cleanup import service


def _age(path, *, now: datetime, days: int) -> None:
    timestamp = (now - timedelta(days=days)).timestamp()
    os.utime(path, (timestamp, timestamp))


def test_preview_and_apply_only_touch_allowlisted_old_files(tmp_path, monkeypatch) -> None:
    now = datetime(2026, 8, 26, tzinfo=UTC)
    data_dir = tmp_path / "data"
    archive_dir = data_dir / "conversation-archive"
    debug_dir = data_dir / "debug" / "response-create-dumps"
    temp_dir = data_dir / ".tmp" / "provider-retag"
    for directory in (archive_dir, debug_dir, temp_dir):
        directory.mkdir(parents=True)

    old_archive = archive_dir / "2026-01-01.jsonl.gz"
    fresh_archive = archive_dir / "2026-08-25.jsonl"
    unrelated = archive_dir / "notes.txt"
    old_dump = debug_dir / "20260101T000000-deadbeef.response-create.json.gz"
    old_temp = temp_dir / "state.sqlite"
    for path, content in (
        (old_archive, b"archive"),
        (fresh_archive, b"fresh"),
        (unrelated, b"keep"),
        (old_dump, b"dump"),
        (old_temp, b"temp"),
    ):
        path.write_bytes(content)
    for path in (old_archive, old_dump, old_temp, unrelated):
        _age(path, now=now, days=90)
    _age(fresh_archive, now=now, days=1)

    monkeypatch.setattr(
        service,
        "get_settings",
        lambda: SimpleNamespace(data_dir=data_dir, conversation_archive_dir=archive_dir),
    )
    categories = ["conversation_archives", "debug_dumps", "temporary_files"]
    preview = service.preview_cleanup(categories=categories, older_than_days=30, now=now)

    assert len(preview.candidates) == 3
    assert preview.total_bytes == len(b"archive") + len(b"dump") + len(b"temp")
    assert all(not item.path.is_symlink() for item in preview.candidates)

    result = service.apply_cleanup(
        categories=categories,
        older_than_days=30,
        confirmation_token=preview.confirmation_token,
        now=now + timedelta(minutes=1),
    )
    assert result.deleted_files == 3
    assert result.skipped_files == 0
    assert not old_archive.exists()
    assert not old_dump.exists()
    assert not old_temp.exists()
    assert fresh_archive.exists()
    assert unrelated.exists()


def test_apply_requires_a_fresh_exact_preview(tmp_path, monkeypatch) -> None:
    now = datetime(2026, 8, 26, tzinfo=UTC)
    data_dir = tmp_path / "data"
    archive_dir = data_dir / "conversation-archive"
    archive_dir.mkdir(parents=True)
    path = archive_dir / "2026-01-01.jsonl"
    path.write_text("before", encoding="utf-8")
    _age(path, now=now, days=90)
    monkeypatch.setattr(
        service,
        "get_settings",
        lambda: SimpleNamespace(data_dir=data_dir, conversation_archive_dir=archive_dir),
    )

    preview = service.preview_cleanup(
        categories=["conversation_archives"], older_than_days=30, now=now
    )
    path.write_text("changed after preview", encoding="utf-8")
    _age(path, now=now, days=90)

    with pytest.raises(service.StorageCleanupPreviewChangedError):
        service.apply_cleanup(
            categories=["conversation_archives"],
            older_than_days=30,
            confirmation_token=preview.confirmation_token,
            now=now,
        )
    assert path.exists()


def test_preview_ignores_symlinks_when_supported(tmp_path, monkeypatch) -> None:
    now = datetime(2026, 8, 26, tzinfo=UTC)
    data_dir = tmp_path / "data"
    archive_dir = data_dir / "conversation-archive"
    archive_dir.mkdir(parents=True)
    outside = tmp_path / "outside.jsonl"
    outside.write_text("protected", encoding="utf-8")
    link = archive_dir / "2026-01-01.jsonl"
    try:
        link.symlink_to(outside)
    except OSError:
        pytest.skip("Symlink creation is unavailable on this Windows host")
    monkeypatch.setattr(
        service,
        "get_settings",
        lambda: SimpleNamespace(data_dir=data_dir, conversation_archive_dir=archive_dir),
    )
    preview = service.preview_cleanup(
        categories=["conversation_archives"], older_than_days=1, now=now
    )
    assert preview.candidates == ()
    assert outside.exists()
