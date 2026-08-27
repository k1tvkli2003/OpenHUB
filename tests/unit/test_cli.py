from __future__ import annotations

import logging
import sqlite3
import sys
from types import SimpleNamespace
from typing import Any

import pytest

from app import cli
from app.core.runtime_logging import UtcDefaultFormatter

pytestmark = pytest.mark.unit


def test_main_passes_timestamped_log_config(monkeypatch):
    captured: dict[str, Any] = {}

    def fake_run(*args, **kwargs):
        captured["args"] = args
        captured["kwargs"] = kwargs

    monkeypatch.setattr(sys, "argv", ["openhub"])
    monkeypatch.setattr(cli, "_load_uvicorn", lambda: SimpleNamespace(run=fake_run))

    cli.main()

    kwargs = captured["kwargs"]
    assert isinstance(kwargs, dict)
    log_config = kwargs["log_config"]
    assert isinstance(log_config, dict)
    formatters = log_config["formatters"]
    assert formatters["default"]["fmt"].startswith("%(asctime)s ")
    assert formatters["access"]["fmt"].startswith("%(asctime)s ")
    assert kwargs["timeout_keep_alive"] == 7200
    assert kwargs["ws_max_size"] == 128 * 1024 * 1024
    assert kwargs["proxy_headers"] is False


def test_main_passes_custom_keep_alive_timeout(monkeypatch):
    captured: dict[str, Any] = {}

    def fake_run(*args, **kwargs):
        captured["args"] = args
        captured["kwargs"] = kwargs

    monkeypatch.setattr(sys, "argv", ["openhub", "--timeout-keep-alive", "900"])
    monkeypatch.setattr(cli, "_load_uvicorn", lambda: SimpleNamespace(run=fake_run))

    cli.main()

    assert captured["kwargs"]["timeout_keep_alive"] == 900


def test_main_passes_custom_ws_max_size_flag(monkeypatch):
    captured: dict[str, Any] = {}

    def fake_run(*args, **kwargs):
        captured["args"] = args
        captured["kwargs"] = kwargs

    monkeypatch.setattr(sys, "argv", ["openhub", "--ws-max-size", "33554432"])
    monkeypatch.setattr(cli, "_load_uvicorn", lambda: SimpleNamespace(run=fake_run))

    cli.main()

    assert captured["kwargs"]["ws_max_size"] == 33554432


def test_main_reads_ws_max_size_from_env(monkeypatch):
    captured: dict[str, Any] = {}

    def fake_run(*args, **kwargs):
        captured["args"] = args
        captured["kwargs"] = kwargs

    monkeypatch.setattr(sys, "argv", ["openhub"])
    monkeypatch.setenv("UVICORN_WS_MAX_SIZE", "67108864")
    monkeypatch.setattr(cli, "_load_uvicorn", lambda: SimpleNamespace(run=fake_run))

    cli.main()

    assert captured["kwargs"]["ws_max_size"] == 67108864


def test_main_ws_max_size_flag_overrides_env(monkeypatch):
    captured: dict[str, Any] = {}

    def fake_run(*args, **kwargs):
        captured["args"] = args
        captured["kwargs"] = kwargs

    monkeypatch.setattr(sys, "argv", ["openhub", "--ws-max-size", "33554432"])
    monkeypatch.setenv("UVICORN_WS_MAX_SIZE", "67108864")
    monkeypatch.setattr(cli, "_load_uvicorn", lambda: SimpleNamespace(run=fake_run))

    cli.main()

    assert captured["kwargs"]["ws_max_size"] == 33554432


def test_main_reports_invalid_ws_max_size_env(monkeypatch):
    monkeypatch.setattr(sys, "argv", ["openhub"])
    monkeypatch.setenv("UVICORN_WS_MAX_SIZE", "not-a-size")

    with pytest.raises(SystemExit, match="--ws-max-size/UVICORN_WS_MAX_SIZE must be an integer"):
        cli.main()


def test_main_reports_non_positive_ws_max_size(monkeypatch):
    monkeypatch.setattr(sys, "argv", ["openhub", "--ws-max-size", "0"])

    with pytest.raises(SystemExit, match="--ws-max-size/UVICORN_WS_MAX_SIZE must be positive"):
        cli.main()


@pytest.mark.parametrize("source", ["flag", "env"])
def test_main_reports_invalid_server_port_before_loading_uvicorn(monkeypatch, source):
    def fail_load_uvicorn():
        pytest.fail("Uvicorn must not load for a non-integer server port")

    if source == "flag":
        monkeypatch.setenv("PORT", "2455")
        argv = ["--port", "not-a-port"]
    else:
        monkeypatch.setenv("PORT", "not-a-port")
        argv = []
    monkeypatch.setattr(cli, "_load_uvicorn", fail_load_uvicorn)

    with pytest.raises(SystemExit) as exc_info:
        cli.main(argv)

    assert str(exc_info.value) == ("--port/PORT must be an integer between 0 and 65535 inclusive, got 'not-a-port'.")


@pytest.mark.parametrize("source", ["flag", "env"])
@pytest.mark.parametrize("raw_port", ["-1", "65536", "70000"])
def test_main_rejects_out_of_range_server_port_before_loading_uvicorn(monkeypatch, source, raw_port):
    def fail_load_uvicorn():
        pytest.fail("Uvicorn must not load for an out-of-range server port")

    if source == "flag":
        monkeypatch.setenv("PORT", "2455")
        argv = ["--port", raw_port]
    else:
        monkeypatch.setenv("PORT", raw_port)
        argv = []
    monkeypatch.setattr(cli, "_load_uvicorn", fail_load_uvicorn)

    with pytest.raises(SystemExit, match=r"--port/PORT must be between 0 and 65535 inclusive"):
        cli.main(argv)


@pytest.mark.parametrize("source", ["flag", "env"])
@pytest.mark.parametrize("raw_port", ["0", "65535"])
def test_main_forwards_server_port_boundaries(monkeypatch, source, raw_port):
    captured: dict[str, Any] = {}

    def fake_run(*args, **kwargs):
        captured["kwargs"] = kwargs

    if source == "flag":
        monkeypatch.setenv("PORT", "70000")
        argv = ["--port", raw_port]
    else:
        monkeypatch.setenv("PORT", raw_port)
        argv = []
    monkeypatch.setattr(cli, "_load_uvicorn", lambda: SimpleNamespace(run=fake_run))

    cli.main(argv)

    assert captured["kwargs"]["port"] == int(raw_port)


def test_main_reports_invalid_keep_alive_timeout_env(monkeypatch):
    monkeypatch.setattr(sys, "argv", ["openhub"])
    monkeypatch.setenv("UVICORN_TIMEOUT_KEEP_ALIVE", "not-a-timeout")

    with pytest.raises(SystemExit, match="--timeout-keep-alive/UVICORN_TIMEOUT_KEEP_ALIVE must be an integer"):
        cli.main()


def test_codex_sessions_retag_command_is_not_exposed(capsys):
    with pytest.raises(SystemExit) as exc_info:
        cli.main(["codex-sessions", "retag"])
    assert exc_info.value.code == 2
    assert "invalid choice: 'codex-sessions'" in capsys.readouterr().err


def test_data_integrity_check_validates_explicit_copy_without_loading_uvicorn(monkeypatch, capsys, tmp_path):
    database = tmp_path / "store-copy.db"
    with sqlite3.connect(database) as conn:
        conn.execute("CREATE TABLE sentinel (id INTEGER PRIMARY KEY)")

    monkeypatch.setenv("PORT", "not-a-port")
    monkeypatch.setattr(cli, "_load_uvicorn", lambda: pytest.fail("Uvicorn must not load for data inspection"))

    cli.main(["data", "integrity-check", "--database", str(database)])

    assert capsys.readouterr().out.strip() == "sqlite_integrity=ok"


def test_data_integrity_check_rejects_corrupt_copy(monkeypatch, tmp_path):
    database = tmp_path / "corrupt.db"
    database.write_bytes(b"not a sqlite database")
    monkeypatch.setattr(cli, "_load_uvicorn", lambda: pytest.fail("Uvicorn must not load for data inspection"))

    with pytest.raises(SystemExit, match="SQLite integrity check failed"):
        cli.main(["data", "integrity-check", "--database", str(database)])


def test_data_integrity_check_rejects_missing_copy(monkeypatch, tmp_path):
    database = tmp_path / "missing.db"
    monkeypatch.setattr(cli, "_load_uvicorn", lambda: pytest.fail("Uvicorn must not load for data inspection"))

    with pytest.raises(SystemExit, match="SQLite database does not exist"):
        cli.main(["data", "integrity-check", "--database", str(database)])


def test_utc_default_formatter_formats_without_converter_binding_error():
    formatter = UtcDefaultFormatter(
        fmt="%(asctime)s %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%SZ",
        use_colors=None,
    )
    record = logging.LogRecord(
        name="uvicorn.error",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="hello",
        args=(),
        exc_info=None,
    )
    record.created = 0.0

    assert formatter.format(record) == "1970-01-01T00:00:00Z hello"
