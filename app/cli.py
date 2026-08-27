from __future__ import annotations

import argparse
import os
from collections.abc import Sequence
from pathlib import Path
from typing import TYPE_CHECKING

from app.db.sqlite_utils import check_sqlite_integrity

if TYPE_CHECKING:
    from app.core.runtime_logging import LogConfig


class _CliHelpFormatter(argparse.HelpFormatter):
    def __init__(self, prog: str) -> None:
        super().__init__(prog, max_help_position=36, width=120)


def _parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the openhub API server.",
        formatter_class=_CliHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="command")

    data = subparsers.add_parser(
        "data",
        help="Inspect local openhub data without starting the server.",
        formatter_class=_CliHelpFormatter,
    )
    data_subparsers = data.add_subparsers(dest="data_command")
    integrity_check = data_subparsers.add_parser(
        "integrity-check",
        help="Run SQLite's full integrity check against an explicit database copy.",
        formatter_class=_CliHelpFormatter,
    )
    integrity_check.add_argument(
        "--database",
        type=Path,
        required=True,
        metavar="PATH",
        help="SQLite database file to inspect. The server and migrations are not started.",
    )

    parser.add_argument("--host", default=os.getenv("HOST", "127.0.0.1"))
    parser.add_argument("--port", default=os.getenv("PORT", "2455"))
    parser.add_argument("--ssl-certfile", default=os.getenv("SSL_CERTFILE"))
    parser.add_argument("--ssl-keyfile", default=os.getenv("SSL_KEYFILE"))
    parser.add_argument(
        "--timeout-keep-alive",
        default=os.getenv("UVICORN_TIMEOUT_KEEP_ALIVE", "7200"),
        help=(
            "Seconds to keep idle HTTP connections open. Codex CLI reuses local "
            "connections for large compact POSTs; short keepalive windows can leave the "
            "client writing to a stale socket before the request reaches the app."
        ),
    )
    parser.add_argument(
        "--ws-max-size",
        default=os.getenv("UVICORN_WS_MAX_SIZE", str(128 * 1024 * 1024)),
        help=(
            "Maximum decompressed size in bytes of a single incoming websocket message. "
            "Codex clients resend the full conversation history (inline screenshots "
            "included) as one response.create message after a reconnect; messages above "
            "this budget are closed at the protocol layer with 1009 before the "
            "application-level slimming guard can run."
        ),
    )

    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> None:
    args = _parse_args(argv)

    if args.command == "data":
        if args.data_command == "integrity-check":
            _run_data_integrity_check(args.database)
            return
        raise SystemExit("data requires a subcommand")

    if bool(args.ssl_certfile) ^ bool(args.ssl_keyfile):
        raise SystemExit("Both --ssl-certfile and --ssl-keyfile must be provided together.")

    port = _parse_server_port(args.port)
    timeout_keep_alive = _parse_server_timeout_keep_alive(args.timeout_keep_alive)
    ws_max_size = _parse_server_ws_max_size(args.ws_max_size)
    os.environ["PORT"] = str(port)

    _load_uvicorn().run(
        "app.main:app",
        host=args.host,
        port=port,
        ssl_certfile=args.ssl_certfile,
        ssl_keyfile=args.ssl_keyfile,
        timeout_keep_alive=timeout_keep_alive,
        ws_max_size=ws_max_size,
        proxy_headers=False,
        log_config=_build_log_config(),
    )


def _load_uvicorn():
    import uvicorn

    return uvicorn


def _build_log_config() -> "LogConfig":
    from app.core.runtime_logging import build_log_config

    return build_log_config()


def _run_data_integrity_check(database: Path) -> None:
    resolved = database.expanduser().resolve()
    if not resolved.is_file():
        raise SystemExit(f"SQLite database does not exist: {resolved}")

    result = check_sqlite_integrity(resolved)
    if not result.ok:
        details = result.details or "unknown integrity failure"
        raise SystemExit(f"SQLite integrity check failed for {resolved}: {details}")
    print("sqlite_integrity=ok")


def _parse_server_port(raw_port: str) -> int:
    try:
        port = int(raw_port)
    except ValueError as exc:
        raise SystemExit(f"--port/PORT must be an integer between 0 and 65535 inclusive, got {raw_port!r}.") from exc
    if not 0 <= port <= 65535:
        raise SystemExit(f"--port/PORT must be between 0 and 65535 inclusive, got {raw_port!r}.")
    return port


def _parse_server_timeout_keep_alive(raw_timeout: str) -> int:
    try:
        return int(raw_timeout)
    except ValueError as exc:
        message = f"--timeout-keep-alive/UVICORN_TIMEOUT_KEEP_ALIVE must be an integer, got {raw_timeout!r}."
        raise SystemExit(message) from exc


def _parse_server_ws_max_size(raw_ws_max_size: str) -> int:
    try:
        ws_max_size = int(raw_ws_max_size)
    except ValueError as exc:
        message = f"--ws-max-size/UVICORN_WS_MAX_SIZE must be an integer, got {raw_ws_max_size!r}."
        raise SystemExit(message) from exc
    if ws_max_size <= 0:
        raise SystemExit(f"--ws-max-size/UVICORN_WS_MAX_SIZE must be positive, got {raw_ws_max_size!r}.")
    return ws_max_size


if __name__ == "__main__":
    main()
