from __future__ import annotations

import json
import os
import socket
import sqlite3
import threading
from collections import deque
from collections.abc import Callable, Iterable
from contextlib import closing
from dataclasses import dataclass, replace
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Literal

RuntimeId = Literal["codex", "hermes", "opencode"]

_RECONNECT_GRACE = timedelta(seconds=20)
_MAX_TASKS_PER_RUNTIME = 200
_MAX_ROLLOUT_IDENTITY_BYTES = 128 * 1024
_FAILED_REASON_WORDS = ("error", "failed", "exception", "crash")


@dataclass(frozen=True, slots=True)
class RuntimeCapabilities:
    open: bool = False
    pause: bool = False
    resume: bool = False
    stop: bool = False


@dataclass(frozen=True, slots=True)
class RuntimeUsage:
    input_tokens: int = 0
    output_tokens: int = 0
    cache_read_tokens: int = 0
    cache_write_tokens: int = 0
    reasoning_tokens: int = 0
    total_tokens: int = 0
    session_tokens: int = 0

    def plus(self, other: RuntimeUsage) -> RuntimeUsage:
        return RuntimeUsage(
            input_tokens=self.input_tokens + other.input_tokens,
            output_tokens=self.output_tokens + other.output_tokens,
            cache_read_tokens=self.cache_read_tokens + other.cache_read_tokens,
            cache_write_tokens=self.cache_write_tokens + other.cache_write_tokens,
            reasoning_tokens=self.reasoning_tokens + other.reasoning_tokens,
            total_tokens=self.total_tokens + other.total_tokens,
            session_tokens=self.session_tokens + other.session_tokens,
        )


@dataclass(frozen=True, slots=True)
class RuntimeTask:
    native_id: str
    runtime: RuntimeId
    title: str
    provider: str
    model: str
    state: str
    usage: RuntimeUsage
    cwd: str | None = None
    parent_native_id: str | None = None
    root_native_id: str | None = None
    started_at: datetime | None = None
    last_activity_at: datetime | None = None
    ended_at: datetime | None = None
    capabilities: RuntimeCapabilities = RuntimeCapabilities()
    uncertain: bool = False
    error_summary: str | None = None
    root_id: str = ""
    parent_id: str | None = None
    child_count: int = 0
    aggregate_usage: RuntimeUsage = RuntimeUsage()

    @property
    def id(self) -> str:
        return f"{self.runtime}:{self.native_id}"

    @property
    def is_root(self) -> bool:
        return self.root_id == self.id


@dataclass(frozen=True, slots=True)
class RuntimeHealth:
    runtime: RuntimeId
    status: str
    database_path: Path
    gateway_reachable: bool | None = None
    reconnect_deadline: datetime | None = None
    message: str | None = None


@dataclass(frozen=True, slots=True)
class UsageWindow:
    since_start: int
    last_minute: int
    last_hour: int
    started_at: datetime


@dataclass(frozen=True, slots=True)
class RuntimeSnapshot:
    sampled_at: datetime
    tasks: tuple[RuntimeTask, ...]
    health: tuple[RuntimeHealth, ...]
    usage_total: UsageWindow
    usage_codex: UsageWindow
    usage_hermes: UsageWindow
    usage_opencode: UsageWindow
    reconnect_grace_seconds: int = 20


@dataclass(slots=True)
class _AdapterCache:
    tasks: tuple[RuntimeTask, ...] = ()
    failure_since: datetime | None = None
    last_error: str | None = None


@dataclass(frozen=True, slots=True)
class _TokenDelta:
    at: datetime
    runtime: RuntimeId
    tokens: int


Reader = Callable[[], Iterable[RuntimeTask]]


class RuntimeControlService:
    def __init__(
        self,
        *,
        codex_home: Path | None = None,
        hermes_home: Path | None = None,
        opencode_data_home: Path | None = None,
        now: Callable[[], datetime] | None = None,
        codex_reader: Reader | None = None,
        hermes_reader: Reader | None = None,
        opencode_reader: Reader | None = None,
    ) -> None:
        self.codex_home = (codex_home or _default_codex_home()).resolve()
        self.hermes_home = (hermes_home or _default_hermes_home()).resolve()
        self.opencode_data_home = (opencode_data_home or _default_opencode_data_home()).resolve()
        self._clock = now or (lambda: datetime.now(UTC))
        self._codex_reader = codex_reader or self._read_codex_tasks
        self._hermes_reader = hermes_reader or self._read_hermes_tasks
        self._opencode_reader = opencode_reader or self._read_opencode_tasks
        self._lock = threading.RLock()
        self._started_at = _as_utc(self._clock())
        self._adapter_cache: dict[RuntimeId, _AdapterCache] = {
            "codex": _AdapterCache(),
            "hermes": _AdapterCache(),
            "opencode": _AdapterCache(),
        }
        self._last_totals: dict[str, int] = {}
        self._session_totals: dict[str, int] = {}
        self._deltas: deque[_TokenDelta] = deque()

    def snapshot(self) -> RuntimeSnapshot:
        with self._lock:
            now = _as_utc(self._clock())
            codex_tasks, codex_health = self._read_with_grace(
                "codex", self._codex_reader, self.codex_home / "state_5.sqlite", now
            )
            hermes_tasks, hermes_health = self._read_with_grace(
                "hermes", self._hermes_reader, self.hermes_home / "state.db", now
            )
            opencode_tasks, opencode_health = self._read_with_grace(
                "opencode",
                self._opencode_reader,
                self.opencode_data_home / "opencode.db",
                now,
            )
            tasks = _attach_lineage((*codex_tasks, *hermes_tasks, *opencode_tasks))
            tasks = self._record_usage(tasks, now)
            ordered = tuple(sorted(tasks, key=_task_sort_key))
            return RuntimeSnapshot(
                sampled_at=now,
                tasks=ordered,
                health=(codex_health, hermes_health, opencode_health),
                usage_total=self._usage_window(now, None),
                usage_codex=self._usage_window(now, "codex"),
                usage_hermes=self._usage_window(now, "hermes"),
                usage_opencode=self._usage_window(now, "opencode"),
            )

    def _read_with_grace(
        self,
        runtime: RuntimeId,
        reader: Reader,
        database_path: Path,
        now: datetime,
    ) -> tuple[tuple[RuntimeTask, ...], RuntimeHealth]:
        cache = self._adapter_cache[runtime]
        if not database_path.is_file() and reader in {
            self._codex_reader,
            self._hermes_reader,
            self._opencode_reader,
        }:
            return (), RuntimeHealth(
                runtime=runtime,
                status="unavailable",
                database_path=database_path,
                gateway_reachable=_runtime_gateway_reachable(runtime),
                message="Runtime state database was not found.",
            )
        try:
            tasks = tuple(reader())
        except Exception as exc:
            bounded = _bounded_message(exc)
            if cache.failure_since is None:
                cache.failure_since = now
            cache.last_error = bounded
            elapsed = now - cache.failure_since
            reconnecting = elapsed < _RECONNECT_GRACE
            deadline = cache.failure_since + _RECONNECT_GRACE
            stale_tasks = tuple(replace(task, uncertain=True) for task in cache.tasks)
            return stale_tasks, RuntimeHealth(
                runtime=runtime,
                status="reconnecting" if reconnecting else "degraded",
                database_path=database_path,
                gateway_reachable=_runtime_gateway_reachable(runtime),
                reconnect_deadline=deadline if reconnecting else None,
                message=None if reconnecting else bounded,
            )

        cache.tasks = tasks
        cache.failure_since = None
        cache.last_error = None
        return tasks, RuntimeHealth(
            runtime=runtime,
            status="available",
            database_path=database_path,
            gateway_reachable=_runtime_gateway_reachable(runtime),
        )

    def _record_usage(self, tasks: tuple[RuntimeTask, ...], now: datetime) -> tuple[RuntimeTask, ...]:
        own_session: dict[str, int] = {}
        for task in tasks:
            current = max(0, task.usage.total_tokens)
            previous = self._last_totals.get(task.id)
            self._last_totals[task.id] = current
            if previous is not None and current > previous:
                delta = current - previous
                self._session_totals[task.id] = self._session_totals.get(task.id, 0) + delta
                self._deltas.append(_TokenDelta(at=now, runtime=task.runtime, tokens=delta))
            own_session[task.id] = self._session_totals.get(task.id, 0)

        cutoff = now - timedelta(hours=1)
        while self._deltas and self._deltas[0].at < cutoff:
            self._deltas.popleft()

        with_session = tuple(
            replace(task, usage=replace(task.usage, session_tokens=own_session.get(task.id, 0)))
            for task in tasks
        )
        return _attach_lineage(with_session)

    def _usage_window(self, now: datetime, runtime: RuntimeId | None) -> UsageWindow:
        minute_cutoff = now - timedelta(minutes=1)
        hour_cutoff = now - timedelta(hours=1)
        relevant = tuple(delta for delta in self._deltas if runtime is None or delta.runtime == runtime)
        return UsageWindow(
            since_start=sum(
                value
                for key, value in self._session_totals.items()
                if runtime is None or key.startswith(f"{runtime}:")
            ),
            last_minute=sum(delta.tokens for delta in relevant if delta.at >= minute_cutoff),
            last_hour=sum(delta.tokens for delta in relevant if delta.at >= hour_cutoff),
            started_at=self._started_at,
        )

    def _read_codex_tasks(self) -> Iterable[RuntimeTask]:
        database_path = self.codex_home / "state_5.sqlite"
        with closing(_readonly_sqlite(database_path)) as connection:
            rows = connection.execute(
                """
                SELECT id, rollout_path, created_at, updated_at, model_provider,
                       cwd, title, tokens_used, model, created_at_ms,
                       updated_at_ms, recency_at_ms
                FROM threads
                WHERE archived = 0
                ORDER BY recency_at_ms DESC, updated_at DESC
                LIMIT ?
                """,
                (_MAX_TASKS_PER_RUNTIME,),
            ).fetchall()
        now = _as_utc(self._clock())
        for row in rows:
            identity = _codex_rollout_identity(Path(row["rollout_path"]), str(row["id"]))
            last_activity = _timestamp(row["updated_at_ms"] or row["recency_at_ms"] or row["updated_at"])
            yield RuntimeTask(
                native_id=str(row["id"]),
                runtime="codex",
                title=_safe_title(row["title"], "Untitled Codex task"),
                provider=_safe_text(row["model_provider"], "OpenAI"),
                model=_safe_text(row["model"], "unknown"),
                state=_active_state(last_activity, now),
                usage=RuntimeUsage(total_tokens=_nonnegative_int(row["tokens_used"])),
                cwd=_optional_text(row["cwd"]),
                parent_native_id=identity[1],
                root_native_id=identity[0],
                started_at=_timestamp(row["created_at_ms"] or row["created_at"]),
                last_activity_at=last_activity,
                capabilities=RuntimeCapabilities(open=True),
            )

    def _read_hermes_tasks(self) -> Iterable[RuntimeTask]:
        database_path = self.hermes_home / "state.db"
        with closing(_readonly_sqlite(database_path)) as connection:
            rows = connection.execute(
                """
                SELECT id, source, model, parent_session_id, started_at,
                       ended_at, end_reason, input_tokens, output_tokens,
                       cache_read_tokens, cache_write_tokens, reasoning_tokens,
                       cwd, billing_provider, title, display_name,
                       last_activity_at
                FROM sessions
                WHERE archived = 0 AND hidden = 0
                ORDER BY COALESCE(last_activity_at, started_at) DESC
                LIMIT ?
                """,
                (_MAX_TASKS_PER_RUNTIME,),
            ).fetchall()
        now = _as_utc(self._clock())
        for row in rows:
            ended_at = _timestamp(row["ended_at"])
            last_activity = _timestamp(row["last_activity_at"] or row["started_at"])
            end_reason = _optional_text(row["end_reason"])
            state = _hermes_state(ended_at, end_reason, last_activity, now)
            input_tokens = _nonnegative_int(row["input_tokens"])
            output_tokens = _nonnegative_int(row["output_tokens"])
            cache_read_tokens = _nonnegative_int(row["cache_read_tokens"])
            cache_write_tokens = _nonnegative_int(row["cache_write_tokens"])
            reasoning_tokens = _nonnegative_int(row["reasoning_tokens"])
            total_tokens = (
                input_tokens
                + output_tokens
                + cache_read_tokens
                + cache_write_tokens
                + reasoning_tokens
            )
            model = _safe_text(row["model"], "unknown")
            yield RuntimeTask(
                native_id=str(row["id"]),
                runtime="hermes",
                title=_safe_title(row["title"] or row["display_name"], "Untitled Hermes task"),
                provider=_safe_text(row["billing_provider"], _provider_from_model(model)),
                model=model,
                state=state,
                usage=RuntimeUsage(
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                    cache_read_tokens=cache_read_tokens,
                    cache_write_tokens=cache_write_tokens,
                    reasoning_tokens=reasoning_tokens,
                    total_tokens=total_tokens,
                ),
                cwd=_optional_text(row["cwd"]),
                parent_native_id=_optional_text(row["parent_session_id"]),
                started_at=_timestamp(row["started_at"]),
                last_activity_at=last_activity,
                ended_at=ended_at,
                capabilities=RuntimeCapabilities(
                    open=True,
                    resume=state not in {"active", "reasoning", "tool"},
                    stop=state in {"active", "reasoning", "tool", "retrying", "stalled"},
                ),
                error_summary=end_reason if state == "failed" else None,
            )

    def _read_opencode_tasks(self) -> Iterable[RuntimeTask]:
        database_path = self.opencode_data_home / "opencode.db"
        with closing(_readonly_sqlite(database_path)) as connection:
            rows = connection.execute(
                """
                SELECT id, parent_id, directory, title, model,
                       time_created, time_updated, time_archived,
                       tokens_input, tokens_output, tokens_reasoning,
                       tokens_cache_read, tokens_cache_write
                FROM session
                WHERE time_archived IS NULL
                ORDER BY time_updated DESC
                LIMIT ?
                """,
                (_MAX_TASKS_PER_RUNTIME,),
            ).fetchall()
        now = _as_utc(self._clock())
        for row in rows:
            model, provider = _opencode_model(row["model"])
            input_tokens = _nonnegative_int(row["tokens_input"])
            output_tokens = _nonnegative_int(row["tokens_output"])
            reasoning_tokens = _nonnegative_int(row["tokens_reasoning"])
            cache_read_tokens = _nonnegative_int(row["tokens_cache_read"])
            cache_write_tokens = _nonnegative_int(row["tokens_cache_write"])
            total_tokens = (
                input_tokens
                + output_tokens
                + reasoning_tokens
                + cache_read_tokens
                + cache_write_tokens
            )
            last_activity = _timestamp(row["time_updated"])
            state = _active_state(last_activity, now)
            yield RuntimeTask(
                native_id=str(row["id"]),
                runtime="opencode",
                title=_safe_title(row["title"], "Untitled OpenCode task"),
                provider=provider,
                model=model,
                state=state,
                usage=RuntimeUsage(
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                    cache_read_tokens=cache_read_tokens,
                    cache_write_tokens=cache_write_tokens,
                    reasoning_tokens=reasoning_tokens,
                    total_tokens=total_tokens,
                ),
                cwd=_optional_text(row["directory"]),
                parent_native_id=_optional_text(row["parent_id"]),
                started_at=_timestamp(row["time_created"]),
                last_activity_at=last_activity,
                capabilities=RuntimeCapabilities(
                    open=True,
                    stop=state in {"active", "reasoning", "tool", "retrying", "stalled"},
                ),
            )


def _attach_lineage(tasks: Iterable[RuntimeTask]) -> tuple[RuntimeTask, ...]:
    source = tuple(tasks)
    by_runtime_native = {(task.runtime, task.native_id): task for task in source}

    def root_native(task: RuntimeTask) -> str:
        if task.root_native_id:
            return task.root_native_id
        current = task
        seen = {task.native_id}
        while current.parent_native_id:
            parent_id = current.parent_native_id
            if parent_id in seen:
                break
            seen.add(parent_id)
            parent = by_runtime_native.get((task.runtime, parent_id))
            if parent is None:
                return parent_id
            current = parent
        return current.native_id

    first_pass = tuple(
        replace(
            task,
            root_id=f"{task.runtime}:{root_native(task)}",
            parent_id=(
                f"{task.runtime}:{task.parent_native_id}" if task.parent_native_id else None
            ),
        )
        for task in source
    )
    aggregate: dict[str, RuntimeUsage] = {}
    child_count: dict[str, int] = {}
    for task in first_pass:
        aggregate[task.root_id] = aggregate.get(task.root_id, RuntimeUsage()).plus(task.usage)
        if task.id != task.root_id:
            child_count[task.root_id] = child_count.get(task.root_id, 0) + 1
    return tuple(
        replace(
            task,
            aggregate_usage=aggregate.get(task.root_id, task.usage),
            child_count=child_count.get(task.id, 0) if task.id == task.root_id else 0,
        )
        for task in first_pass
    )


def _codex_rollout_identity(path: Path, fallback: str) -> tuple[str, str | None]:
    try:
        with path.open("rb") as stream:
            raw = stream.read(_MAX_ROLLOUT_IDENTITY_BYTES)
        for line in raw.splitlines()[:32]:
            decoded = json.loads(line)
            if decoded.get("type") != "session_meta":
                continue
            payload = decoded.get("payload")
            if not isinstance(payload, dict):
                continue
            session_id = _safe_text(payload.get("session_id"), fallback)
            parent = _optional_text(payload.get("parent_thread_id"))
            return session_id, parent
    except (OSError, UnicodeError, json.JSONDecodeError, TypeError, ValueError):
        pass
    return fallback, None


def _readonly_sqlite(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True, timeout=0.25)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA query_only = ON")
    return connection


def _default_codex_home() -> Path:
    configured = os.environ.get("CODEX_HOME", "").strip()
    return Path(configured) if configured else Path.home() / ".codex"


def _default_hermes_home() -> Path:
    configured = os.environ.get("HERMES_HOME", "").strip()
    if configured:
        return Path(configured)
    local_app_data = os.environ.get("LOCALAPPDATA", "").strip()
    return Path(local_app_data) / "hermes" if local_app_data else Path.home() / ".hermes"


def _default_opencode_data_home() -> Path:
    configured = os.environ.get("OPENCODE_DATA_HOME", "").strip()
    if configured:
        return Path(configured)
    return Path.home() / ".local" / "share" / "opencode"


def _hermes_gateway_reachable() -> bool:
    try:
        with socket.create_connection(("127.0.0.1", 9119), timeout=0.08):
            return True
    except OSError:
        return False


def _runtime_gateway_reachable(runtime: RuntimeId) -> bool | None:
    if runtime == "hermes":
        return _hermes_gateway_reachable()
    if runtime == "opencode":
        from app.modules.runtime_control.gateway import opencode_server_reachable

        return opencode_server_reachable()
    return None


def _timestamp(value: object) -> datetime | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return None
    if numeric <= 0:
        return None
    if numeric > 10_000_000_000:
        numeric /= 1000
    try:
        return datetime.fromtimestamp(numeric, UTC)
    except (OSError, OverflowError, ValueError):
        return None


def _active_state(last_activity: datetime | None, now: datetime) -> str:
    if last_activity is None:
        return "unknown"
    age = max(timedelta(0), now - last_activity)
    if age <= timedelta(seconds=15):
        return "active"
    if age <= timedelta(seconds=45):
        return "stalled"
    return "idle"


def _hermes_state(
    ended_at: datetime | None,
    end_reason: str | None,
    last_activity: datetime | None,
    now: datetime,
) -> str:
    reason = (end_reason or "").lower()
    if ended_at is not None:
        if any(word in reason for word in _FAILED_REASON_WORDS):
            return "failed"
        if "interrupt" in reason or "cancel" in reason:
            return "cancelled"
        return "idle"
    return _active_state(last_activity, now)


def _provider_from_model(model: str) -> str:
    prefix = model.split("/", 1)[0].strip()
    return prefix if prefix and prefix != model else "Hermes"


def _opencode_model(raw: object) -> tuple[str, str]:
    if isinstance(raw, str) and raw.strip():
        try:
            decoded = json.loads(raw)
        except json.JSONDecodeError:
            decoded = None
        if isinstance(decoded, dict):
            model = _safe_text(decoded.get("id"), "unknown")
            provider = _safe_text(decoded.get("providerID"), "OpenCode")
            return model, provider
        model = raw.strip()[:512]
        return model, _provider_from_model(model)
    return "unknown", "OpenCode"


def _task_sort_key(task: RuntimeTask) -> tuple[int, float, str]:
    state_rank = 0 if task.state in {"active", "reasoning", "tool", "retrying"} else 1
    activity = task.last_activity_at.timestamp() if task.last_activity_at else 0
    return state_rank, -activity, task.id


def _nonnegative_int(value: object) -> int:
    if isinstance(value, bool):
        return 0
    try:
        return max(0, int(value or 0))
    except (TypeError, ValueError):
        return 0


def _safe_text(value: object, fallback: str) -> str:
    text = str(value or "").strip()
    return text[:512] if text else fallback


def _optional_text(value: object) -> str | None:
    text = str(value or "").strip()
    return text[:2048] if text else None


def _safe_title(value: object, fallback: str) -> str:
    return _safe_text(value, fallback)[:240]


def _bounded_message(error: object) -> str:
    message = str(error).replace("\r", " ").replace("\n", " ").strip()
    return message[:500] or type(error).__name__


def _as_utc(value: datetime) -> datetime:
    return value.astimezone(UTC) if value.tzinfo else value.replace(tzinfo=UTC)


_service: RuntimeControlService | None = None
_service_lock = threading.Lock()


def get_runtime_control_service() -> RuntimeControlService:
    global _service
    with _service_lock:
        if _service is None:
            _service = RuntimeControlService()
        return _service


__all__ = [
    "RuntimeCapabilities",
    "RuntimeControlService",
    "RuntimeHealth",
    "RuntimeSnapshot",
    "RuntimeTask",
    "RuntimeUsage",
    "UsageWindow",
    "get_runtime_control_service",
]
