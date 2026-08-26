from __future__ import annotations

import json
import sqlite3
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from app.modules.runtime_control.gateway import RuntimeActionError, RuntimeActionService
from app.modules.runtime_control.service import (
    RuntimeCapabilities,
    RuntimeControlService,
    RuntimeTask,
    RuntimeUsage,
)


def _create_codex_db(home: Path, rollout: Path) -> None:
    home.mkdir(parents=True)
    db = sqlite3.connect(home / "state_5.sqlite")
    db.execute(
        """
        CREATE TABLE threads (
            id TEXT PRIMARY KEY, rollout_path TEXT, created_at INTEGER,
            updated_at INTEGER, model_provider TEXT, cwd TEXT, title TEXT,
            tokens_used INTEGER, model TEXT, created_at_ms INTEGER,
            updated_at_ms INTEGER, recency_at_ms INTEGER, archived INTEGER
        )
        """
    )
    stamp = int(datetime(2026, 8, 26, 12, 0, tzinfo=UTC).timestamp() * 1000)
    db.execute(
        "INSERT INTO threads VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            "codex-root",
            str(rollout),
            stamp // 1000,
            stamp // 1000,
            "openai",
            "C:/repo",
            "Codex root",
            100,
            "gpt-5.6-sol",
            stamp,
            stamp,
            stamp,
            0,
        ),
    )
    db.commit()
    db.close()


def _create_hermes_db(home: Path) -> None:
    home.mkdir(parents=True)
    db = sqlite3.connect(home / "state.db")
    db.execute(
        """
        CREATE TABLE sessions (
            id TEXT PRIMARY KEY, source TEXT, model TEXT,
            parent_session_id TEXT, started_at REAL, ended_at REAL,
            end_reason TEXT, input_tokens INTEGER, output_tokens INTEGER,
            cache_read_tokens INTEGER, cache_write_tokens INTEGER,
            reasoning_tokens INTEGER, cwd TEXT, billing_provider TEXT,
            title TEXT, display_name TEXT, last_activity_at REAL,
            archived INTEGER, hidden INTEGER
        )
        """
    )
    stamp = datetime(2026, 8, 26, 12, 0, tzinfo=UTC).timestamp()
    db.executemany(
        "INSERT INTO sessions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
            (
                "hermes-root",
                "cli",
                "openai/gpt-5.6-sol",
                None,
                stamp,
                None,
                None,
                200,
                40,
                20,
                0,
                10,
                "C:/repo",
                "openai",
                "Hermes root",
                None,
                stamp,
                0,
                0,
            ),
            (
                "hermes-child",
                "subagent",
                "openai/gpt-5.6-terra",
                "hermes-root",
                stamp,
                None,
                None,
                50,
                10,
                0,
                0,
                0,
                "C:/repo",
                "openai",
                "Hermes child",
                None,
                stamp,
                0,
                0,
            ),
        ],
    )
    db.commit()
    db.close()


def _create_opencode_db(data_home: Path) -> None:
    data_home.mkdir(parents=True)
    db = sqlite3.connect(data_home / "opencode.db")
    db.execute(
        """
        CREATE TABLE session (
            id TEXT PRIMARY KEY, parent_id TEXT, directory TEXT, title TEXT,
            model TEXT, time_created INTEGER, time_updated INTEGER,
            time_archived INTEGER, tokens_input INTEGER, tokens_output INTEGER,
            tokens_reasoning INTEGER, tokens_cache_read INTEGER,
            tokens_cache_write INTEGER
        )
        """
    )
    stamp = int(datetime(2026, 8, 26, 12, 0, tzinfo=UTC).timestamp() * 1000)
    db.executemany(
        "INSERT INTO session VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
            (
                "open-root",
                None,
                "C:/repo",
                "OpenCode root",
                json.dumps({"id": "gpt-5.6-sol", "providerID": "openai"}),
                stamp,
                stamp,
                None,
                300,
                60,
                15,
                100,
                0,
            ),
            (
                "open-child",
                "open-root",
                "C:/repo",
                "OpenCode child",
                json.dumps({"id": "x-preview-f-free", "providerID": "opencode"}),
                stamp,
                stamp,
                None,
                80,
                20,
                0,
                0,
                0,
            ),
        ],
    )
    db.commit()
    db.close()


def test_snapshot_keeps_runtime_ids_distinct_and_rolls_children_into_root(tmp_path: Path) -> None:
    now = datetime(2026, 8, 26, 12, 0, 5, tzinfo=UTC)
    rollout = tmp_path / "rollout.jsonl"
    rollout.write_text(
        json.dumps({"type": "session_meta", "payload": {"session_id": "codex-root"}}) + "\n",
        encoding="utf-8",
    )
    codex_home = tmp_path / "codex"
    hermes_home = tmp_path / "hermes"
    opencode_data_home = tmp_path / "opencode"
    _create_codex_db(codex_home, rollout)
    _create_hermes_db(hermes_home)
    _create_opencode_db(opencode_data_home)

    snapshot = RuntimeControlService(
        codex_home=codex_home,
        hermes_home=hermes_home,
        opencode_data_home=opencode_data_home,
        now=lambda: now,
    ).snapshot()
    by_id = {task.id: task for task in snapshot.tasks}

    assert {
        "codex:codex-root",
        "hermes:hermes-root",
        "hermes:hermes-child",
        "opencode:open-root",
        "opencode:open-child",
    } <= by_id.keys()
    assert by_id["hermes:hermes-child"].root_id == "hermes:hermes-root"
    assert by_id["hermes:hermes-root"].child_count == 1
    assert by_id["hermes:hermes-root"].aggregate_usage.total_tokens == 330
    assert by_id["hermes:hermes-child"].is_root is False
    assert by_id["opencode:open-child"].root_id == "opencode:open-root"
    assert by_id["opencode:open-root"].aggregate_usage.total_tokens == 575
    assert by_id["opencode:open-root"].provider == "openai"


def test_reconnect_grace_hides_transient_error_and_backfills_token_delta(tmp_path: Path) -> None:
    clock = [datetime(2026, 8, 26, 12, 0, tzinfo=UTC)]
    hermes_total = [100]
    failing = [False]

    def codex_reader():
        return []

    def hermes_reader():
        if failing[0]:
            raise OSError("temporary database disconnect")
        return [
            RuntimeTask(
                native_id="h1",
                runtime="hermes",
                title="Hermes",
                provider="openai",
                model="gpt",
                state="active",
                usage=RuntimeUsage(total_tokens=hermes_total[0]),
                capabilities=RuntimeCapabilities(stop=True),
            )
        ]

    codex_home = tmp_path / "codex"
    hermes_home = tmp_path / "hermes"
    codex_home.mkdir()
    hermes_home.mkdir()
    (codex_home / "state_5.sqlite").touch()
    (hermes_home / "state.db").touch()
    opencode_data_home = tmp_path / "opencode"
    opencode_data_home.mkdir()
    (opencode_data_home / "opencode.db").touch()
    service = RuntimeControlService(
        codex_home=codex_home,
        hermes_home=hermes_home,
        now=lambda: clock[0],
        codex_reader=codex_reader,
        hermes_reader=hermes_reader,
        opencode_data_home=opencode_data_home,
        opencode_reader=lambda: [],
    )

    first = service.snapshot()
    assert first.usage_hermes.since_start == 0
    failing[0] = True
    clock[0] += timedelta(seconds=10)
    during_grace = service.snapshot()
    hermes_health = next(item for item in during_grace.health if item.runtime == "hermes")
    assert hermes_health.status == "reconnecting"
    assert hermes_health.message is None
    assert during_grace.tasks[0].uncertain is True

    failing[0] = False
    hermes_total[0] = 180
    clock[0] += timedelta(seconds=5)
    recovered = service.snapshot()
    assert recovered.usage_hermes.since_start == 80
    assert recovered.usage_hermes.last_minute == 80
    assert next(item for item in recovered.health if item.runtime == "hermes").status == "available"


@pytest.mark.asyncio
async def test_opencode_control_uses_real_abort_and_rejects_fake_resume() -> None:
    calls: list[str] = []

    async def abort(session_id: str) -> dict[str, object]:
        calls.append(session_id)
        return {"status": "aborted"}

    service = RuntimeActionService(opencode_abort=abort)
    stopped = await service.execute("opencode", "open-root", "stop")
    assert stopped.detail == "aborted"
    assert calls == ["open-root"]

    with pytest.raises(RuntimeActionError, match="not persistent per-task pause") as exc_info:
        await service.execute("opencode", "open-root", "resume")
    assert exc_info.value.unsupported is True


@pytest.mark.asyncio
async def test_hermes_controls_use_real_gateway_primitives_and_reject_fake_pause() -> None:
    calls: list[tuple[str, dict[str, object]]] = []

    async def gateway(method: str, params: dict[str, object]) -> dict[str, object]:
        calls.append((method, params))
        return {"status": "interrupted", "session_id": "h1"}

    service = RuntimeActionService(gateway)
    stopped = await service.execute("hermes", "h1", "stop")
    resumed = await service.execute("hermes", "h1", "resume")
    assert stopped.detail == "interrupted"
    assert resumed.detail == "resumed"
    assert [method for method, _ in calls] == ["session.interrupt", "session.resume"]

    with pytest.raises(RuntimeActionError, match="no persistent per-task pause primitive") as exc_info:
        await service.execute("hermes", "h1", "pause")
    assert exc_info.value.unsupported is True
