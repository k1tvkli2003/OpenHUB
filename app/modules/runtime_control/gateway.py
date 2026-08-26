from __future__ import annotations

import json
import os
import re
import socket
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from ipaddress import ip_address
from pathlib import Path
from urllib.parse import quote, urlsplit
from uuid import uuid4

import aiohttp

_TOKEN_PATTERN = re.compile(rb'window\.__HERMES_SESSION_TOKEN__="([^"\\]{16,512})"')
_MAX_INDEX_BYTES = 2 * 1024 * 1024
_MAX_OPENCODE_LOG_BYTES = 512 * 1024
_OPENCODE_URL_PATTERN = re.compile(
    rb"spawning sidecar\s*\{\s*url:\s*['\"](?P<url>http://[^'\"]+)['\"]"
)


class RuntimeActionError(RuntimeError):
    def __init__(self, message: str, *, code: str, unsupported: bool = False) -> None:
        super().__init__(message)
        self.code = code
        self.unsupported = unsupported


@dataclass(frozen=True, slots=True)
class RuntimeActionResult:
    runtime: str
    native_id: str
    action: str
    detail: str


GatewayCall = Callable[[str, dict[str, object]], Awaitable[dict[str, object]]]
OpenCodeAbort = Callable[[str], Awaitable[dict[str, object]]]


class RuntimeActionService:
    def __init__(
        self,
        gateway_call: GatewayCall | None = None,
        *,
        opencode_abort: OpenCodeAbort | None = None,
    ) -> None:
        self._gateway_call = gateway_call or HermesGatewayClient().call
        self._opencode_abort = opencode_abort or OpenCodeGatewayClient().abort

    async def execute(self, runtime: str, native_id: str, action: str) -> RuntimeActionResult:
        normalized_id = native_id.strip()
        if not normalized_id or len(normalized_id) > 512:
            raise RuntimeActionError("Task id is invalid.", code="runtime_task_id_invalid")
        if runtime == "codex":
            raise RuntimeActionError(
                "Codex task controls are owned by the native Codex app-server connection.",
                code="runtime_action_native_only",
                unsupported=True,
            )
        if runtime == "opencode":
            if action != "stop":
                raise RuntimeActionError(
                    "OpenCode exposes a real abort primitive, but not persistent per-task pause or prompt-free resume.",
                    code="runtime_action_unsupported",
                    unsupported=True,
                )
            result = await self._opencode_abort(normalized_id)
            return RuntimeActionResult(
                runtime=runtime,
                native_id=normalized_id,
                action=action,
                detail=str(result.get("status") or "aborted"),
            )
        if runtime != "hermes":
            raise RuntimeActionError("Runtime is not supported.", code="runtime_not_supported", unsupported=True)
        if action == "pause":
            raise RuntimeActionError(
                "Hermes has no persistent per-task pause primitive; stop the current turn instead.",
                code="runtime_action_unsupported",
                unsupported=True,
            )
        if action == "stop":
            result = await self._gateway_call("session.interrupt", {"session_id": normalized_id})
            detail = str(result.get("status") or "interrupted")
        elif action == "resume":
            await self._gateway_call(
                "session.resume",
                {"session_id": normalized_id, "omit_messages": True, "defer_history": True},
            )
            detail = "resumed"
        else:
            raise RuntimeActionError(
                "Runtime action is not supported.", code="runtime_action_unsupported", unsupported=True
            )
        return RuntimeActionResult(
            runtime=runtime,
            native_id=normalized_id,
            action=action,
            detail=detail,
        )


class HermesGatewayClient:
    def __init__(self, base_url: str = "http://127.0.0.1:9119") -> None:
        self._base_url = _normalize_loopback_base_url(base_url)

    async def call(self, method: str, params: dict[str, object]) -> dict[str, object]:
        timeout = aiohttp.ClientTimeout(total=35, connect=3, sock_read=30)
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                token = await self._discover_token(session)
                ws_url = f"{self._base_url.replace('http://', 'ws://', 1)}/api/ws?token={quote(token)}"
                async with session.ws_connect(ws_url, max_msg_size=2 * 1024 * 1024) as ws:
                    request_id = f"openhub-{uuid4()}"
                    await ws.send_json(
                        {"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}
                    )
                    while True:
                        message = await ws.receive()
                        if message.type == aiohttp.WSMsgType.TEXT:
                            payload = json.loads(message.data)
                            if payload.get("id") != request_id:
                                continue
                            error = payload.get("error")
                            if isinstance(error, dict):
                                raise RuntimeActionError(
                                    _bounded_gateway_message(error.get("message")),
                                    code="hermes_gateway_rejected",
                                )
                            result = payload.get("result")
                            return result if isinstance(result, dict) else {"value": result}
                        if message.type in {
                            aiohttp.WSMsgType.CLOSE,
                            aiohttp.WSMsgType.CLOSED,
                            aiohttp.WSMsgType.ERROR,
                        }:
                            raise RuntimeActionError(
                                "Hermes gateway disconnected before acknowledging the action.",
                                code="hermes_gateway_disconnected",
                            )
        except RuntimeActionError:
            raise
        except (aiohttp.ClientError, TimeoutError, json.JSONDecodeError) as exc:
            raise RuntimeActionError(
                f"Hermes gateway is unavailable: {_bounded_gateway_message(exc)}",
                code="hermes_gateway_unavailable",
            ) from exc

    async def _discover_token(self, session: aiohttp.ClientSession) -> str:
        async with session.get(f"{self._base_url}/") as response:
            if response.status >= 400:
                raise RuntimeActionError(
                    f"Hermes gateway token discovery returned HTTP {response.status}.",
                    code="hermes_gateway_auth_unavailable",
                )
            payload = await response.content.read(_MAX_INDEX_BYTES + 1)
        if len(payload) > _MAX_INDEX_BYTES:
            raise RuntimeActionError(
                "Hermes gateway index exceeded the safe discovery limit.",
                code="hermes_gateway_auth_unavailable",
            )
        match = _TOKEN_PATTERN.search(payload)
        if match is None:
            raise RuntimeActionError(
                "Hermes gateway did not expose a loopback session token.",
                code="hermes_gateway_auth_unavailable",
            )
        return match.group(1).decode("ascii")


class OpenCodeGatewayClient:
    def __init__(self, server_locator: Callable[[], str | None] | None = None) -> None:
        self._server_locator = server_locator or discover_opencode_server_url

    async def abort(self, session_id: str) -> dict[str, object]:
        base_url = self._server_locator()
        if base_url is None:
            raise RuntimeActionError(
                "OpenCode's loopback server is not currently reachable.",
                code="opencode_server_unavailable",
            )
        timeout = aiohttp.ClientTimeout(total=8, connect=2, sock_read=5)
        endpoint = f"{base_url}/session/{quote(session_id, safe='')}/abort"
        try:
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(endpoint) as response:
                    if response.status >= 400:
                        raise RuntimeActionError(
                            f"OpenCode rejected abort with HTTP {response.status}.",
                            code="opencode_abort_rejected",
                        )
                    payload = await response.json(content_type=None)
        except RuntimeActionError:
            raise
        except (aiohttp.ClientError, TimeoutError, json.JSONDecodeError) as exc:
            raise RuntimeActionError(
                f"OpenCode server is unavailable: {_bounded_gateway_message(exc)}",
                code="opencode_server_unavailable",
            ) from exc
        if payload is not True and not isinstance(payload, dict):
            raise RuntimeActionError(
                "OpenCode did not acknowledge the abort request.",
                code="opencode_abort_rejected",
            )
        return payload if isinstance(payload, dict) else {"status": "aborted"}


def discover_opencode_server_url(log_root: Path | None = None) -> str | None:
    root = log_root or _default_opencode_log_root()
    try:
        candidates = sorted(
            root.glob("*/main.log"),
            key=lambda path: path.stat().st_mtime_ns,
            reverse=True,
        )[:8]
    except OSError:
        return None
    for path in candidates:
        try:
            size = path.stat().st_size
            with path.open("rb") as stream:
                if size > _MAX_OPENCODE_LOG_BYTES:
                    stream.seek(size - _MAX_OPENCODE_LOG_BYTES)
                raw = stream.read(_MAX_OPENCODE_LOG_BYTES)
        except OSError:
            continue
        matches = tuple(_OPENCODE_URL_PATTERN.finditer(raw))
        for match in reversed(matches):
            try:
                candidate = _normalize_loopback_base_url(
                    match.group("url").decode("ascii"), runtime="OpenCode"
                )
            except (UnicodeDecodeError, ValueError):
                continue
            if _tcp_loopback_reachable(candidate):
                return candidate
    return None


def opencode_server_reachable() -> bool:
    return discover_opencode_server_url() is not None


def _default_opencode_log_root() -> Path:
    roaming = os.environ.get("APPDATA", "").strip()
    base = Path(roaming) if roaming else Path.home() / "AppData" / "Roaming"
    return base / "ai.opencode.desktop" / "logs"


def _tcp_loopback_reachable(base_url: str) -> bool:
    parsed = urlsplit(base_url)
    try:
        with socket.create_connection((parsed.hostname or "", parsed.port or 0), timeout=0.08):
            return True
    except OSError:
        return False


def _normalize_loopback_base_url(value: str, *, runtime: str = "Hermes") -> str:
    try:
        parsed = urlsplit(value.strip())
        port = parsed.port
    except ValueError as exc:
        raise ValueError(f"{runtime} gateway URL is invalid.") from exc
    if (
        parsed.scheme != "http"
        or parsed.hostname is None
        or port is None
        or parsed.username
        or parsed.password
        or parsed.query
        or parsed.fragment
        or parsed.path not in {"", "/"}
    ):
        raise ValueError(
            f"{runtime} gateway must be a credential-free numeric loopback HTTP URL."
        )
    try:
        address = ip_address(parsed.hostname)
    except ValueError as exc:
        raise ValueError(f"{runtime} gateway must use a numeric loopback address.") from exc
    if not address.is_loopback:
        raise ValueError(f"{runtime} gateway must stay on loopback.")
    host = f"[{address.compressed}]" if address.version == 6 else address.compressed
    return f"http://{host}:{port}"


def _bounded_gateway_message(value: object) -> str:
    text = str(value or "request failed").replace("\r", " ").replace("\n", " ").strip()
    return text[:400]


_action_service = RuntimeActionService()


def get_runtime_action_service() -> RuntimeActionService:
    return _action_service


__all__ = [
    "HermesGatewayClient",
    "OpenCodeGatewayClient",
    "RuntimeActionError",
    "RuntimeActionResult",
    "RuntimeActionService",
    "discover_opencode_server_url",
    "get_runtime_action_service",
    "opencode_server_reachable",
]
