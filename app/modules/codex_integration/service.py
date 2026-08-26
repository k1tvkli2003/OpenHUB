from __future__ import annotations

import ipaddress
import json
import os
import tempfile
import threading
from dataclasses import dataclass
from datetime import UTC, datetime
from functools import lru_cache
from math import isfinite
from pathlib import Path
from urllib.parse import urlsplit

from app.core.config.settings import get_settings

_MAX_STATE_BYTES = 64 * 1024
_MANAGED_PATH = "/backend-api/codex-managed/v1"


class CodexIntegrationError(RuntimeError):
    pass


class CodexIntegrationConflictError(CodexIntegrationError):
    pass


class CodexLaunchConflictError(CodexIntegrationConflictError):
    pass


@dataclass(frozen=True)
class CodexIntegrationSnapshot:
    state_path: Path
    enabled: bool
    revision: int
    managed_base_url: str
    toggled_at: str | None
    codex_state_policy: str = "never_mutate"


@dataclass(frozen=True)
class CodexIntegrationMutation:
    snapshot: CodexIntegrationSnapshot
    changed: bool


@dataclass(frozen=True)
class CodexLaunchRoute:
    prepared: bool
    selection_mode: str | None
    account_id: str | None
    account_label: str | None
    account_email: str | None
    plan_type: str | None
    effective_remaining_percent: float | None
    primary_remaining_percent: float | None
    secondary_remaining_percent: float | None
    monthly_remaining_percent: float | None
    limiting_remaining_credits: float | None
    sampled_at: str | None
    prepared_at: str | None
    revision: int


@dataclass(frozen=True)
class CodexLaunchRouteMutation:
    route: CodexLaunchRoute
    changed: bool


@dataclass(frozen=True)
class _ModeState:
    enabled: bool
    revision: int
    toggled_at: str | None


class CodexIntegrationService:
    """Owns HUB launch state without reading or writing any Codex-owned file."""

    def __init__(self, data_root: Path | None = None) -> None:
        self._data_root = (data_root or get_settings().data_dir).expanduser().resolve()
        self._mode_state_path = self._data_root / "openhub-managed-launch.json"
        self._launch_state_path = self._data_root / "openhub-launch-route.json"
        self._lock = threading.RLock()
        self._mode_cache: _ModeState | None = None
        self._launch_cache: CodexLaunchRoute | None = None

    def status(self, endpoint: str) -> CodexIntegrationSnapshot:
        normalized_endpoint = _normalize_endpoint(endpoint)
        with self._lock:
            if self._mode_cache is None:
                self._mode_cache = self._read_mode_state()
            return self._snapshot(self._mode_cache, normalized_endpoint)

    def set_enabled(
        self,
        *,
        endpoint: str,
        expected_revision: int,
        enabled: bool,
    ) -> CodexIntegrationMutation:
        normalized_endpoint = _normalize_endpoint(endpoint)
        with self._lock:
            current = self._read_mode_state()
            if current.revision != expected_revision:
                raise CodexIntegrationConflictError(
                    "OpenHUB managed-launch mode changed after it was loaded; refresh and try again."
                )
            if current.enabled is enabled:
                self._mode_cache = current
                return CodexIntegrationMutation(
                    snapshot=self._snapshot(current, normalized_endpoint),
                    changed=False,
                )
            updated = _ModeState(
                enabled=enabled,
                revision=current.revision + 1,
                toggled_at=_utc_now(),
            )
            self._atomic_json_write(
                self._mode_state_path,
                {
                    "version": 1,
                    "enabled": updated.enabled,
                    "revision": updated.revision,
                    "toggled_at": updated.toggled_at,
                },
            )
            verified = self._read_mode_state()
            if verified != updated:
                raise CodexIntegrationError("OpenHUB managed-launch mode failed post-write verification.")
            self._mode_cache = verified
            return CodexIntegrationMutation(
                snapshot=self._snapshot(verified, normalized_endpoint),
                changed=True,
            )

    def launch_route_snapshot(self) -> CodexLaunchRoute:
        with self._lock:
            if self._launch_cache is None:
                self._launch_cache = self._read_launch_route()
            return self._launch_cache

    def prepare_launch_route(
        self,
        *,
        endpoint: str,
        expected_revision: int,
        selection_mode: str,
        account_id: str,
        account_label: str,
        account_email: str,
        plan_type: str,
        effective_remaining_percent: float,
        primary_remaining_percent: float | None,
        secondary_remaining_percent: float | None,
        monthly_remaining_percent: float | None,
        limiting_remaining_credits: float | None,
        sampled_at: str,
    ) -> CodexLaunchRouteMutation:
        _normalize_endpoint(endpoint)
        with self._lock:
            mode = self._read_mode_state()
            if selection_mode not in {"auto", "manual"}:
                raise CodexIntegrationError("Codex launch selection mode is invalid.")
            if selection_mode == "auto" and not mode.enabled:
                raise CodexIntegrationConflictError(
                    "Automatic routing is disabled in OpenHUB; enable it before preparing an automatic launch."
                )
            current = self._read_launch_route()
            if current.revision != expected_revision:
                raise CodexLaunchConflictError(
                    "Codex launch preparation changed after it was loaded; refresh and try again."
                )
            route = CodexLaunchRoute(
                prepared=True,
                selection_mode=selection_mode,
                account_id=account_id,
                account_label=account_label,
                account_email=account_email,
                plan_type=plan_type,
                effective_remaining_percent=effective_remaining_percent,
                primary_remaining_percent=primary_remaining_percent,
                secondary_remaining_percent=secondary_remaining_percent,
                monthly_remaining_percent=monthly_remaining_percent,
                limiting_remaining_credits=limiting_remaining_credits,
                sampled_at=sampled_at,
                prepared_at=_utc_now(),
                revision=current.revision + 1,
            )
            if not _valid_launch_route(route):
                raise CodexIntegrationError("Codex launch route contains invalid selection evidence.")
            self._atomic_json_write(self._launch_state_path, {"version": 1, **route.__dict__})
            verified = self._read_launch_route()
            if verified != route:
                raise CodexIntegrationError("Codex launch route failed post-write verification.")
            self._launch_cache = verified
            return CodexLaunchRouteMutation(route=verified, changed=True)

    def _snapshot(self, state: _ModeState, endpoint: str) -> CodexIntegrationSnapshot:
        return CodexIntegrationSnapshot(
            state_path=self._mode_state_path,
            enabled=state.enabled,
            revision=state.revision,
            managed_base_url=f"{endpoint}{_MANAGED_PATH}",
            toggled_at=state.toggled_at,
        )

    def _read_mode_state(self) -> _ModeState:
        if not self._mode_state_path.exists():
            return _ModeState(enabled=False, revision=0, toggled_at=None)
        payload = self._read_json_object(self._mode_state_path, "OpenHUB managed-launch mode")
        if payload.get("version") != 1:
            raise CodexIntegrationError("OpenHUB managed-launch mode has an unsupported format.")
        state = _ModeState(
            enabled=payload.get("enabled"),
            revision=payload.get("revision"),
            toggled_at=payload.get("toggled_at"),
        )
        if (
            not isinstance(state.enabled, bool)
            or not isinstance(state.revision, int)
            or isinstance(state.revision, bool)
            or state.revision < 0
            or (state.toggled_at is not None and not isinstance(state.toggled_at, str))
        ):
            raise CodexIntegrationError("OpenHUB managed-launch mode is invalid.")
        return state

    def _read_launch_route(self) -> CodexLaunchRoute:
        if not self._launch_state_path.exists():
            return _empty_launch_route()
        payload = self._read_json_object(self._launch_state_path, "Codex launch route")
        if payload.get("version") != 1:
            raise CodexIntegrationError("Codex launch route has an unsupported format.")
        try:
            route = CodexLaunchRoute(
                prepared=payload["prepared"],
                selection_mode=payload["selection_mode"],
                account_id=payload["account_id"],
                account_label=payload["account_label"],
                account_email=payload["account_email"],
                plan_type=payload["plan_type"],
                effective_remaining_percent=payload["effective_remaining_percent"],
                primary_remaining_percent=payload["primary_remaining_percent"],
                secondary_remaining_percent=payload["secondary_remaining_percent"],
                monthly_remaining_percent=payload["monthly_remaining_percent"],
                limiting_remaining_credits=payload["limiting_remaining_credits"],
                sampled_at=payload["sampled_at"],
                prepared_at=payload["prepared_at"],
                revision=payload["revision"],
            )
        except KeyError as exc:
            raise CodexIntegrationError("Codex launch route is incomplete.") from exc
        if not _valid_launch_route(route):
            raise CodexIntegrationError("Codex launch route is invalid.")
        return route

    def _read_json_object(self, path: Path, label: str) -> dict[str, object]:
        if not path.is_file():
            raise CodexIntegrationError(f"{label} path is not a regular file.")
        try:
            if path.stat().st_size > _MAX_STATE_BYTES:
                raise CodexIntegrationError(f"{label} exceeds the safety limit.")
            payload = json.loads(path.read_text(encoding="utf-8"))
        except CodexIntegrationError:
            raise
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise CodexIntegrationError(f"{label} is invalid.") from exc
        if not isinstance(payload, dict):
            raise CodexIntegrationError(f"{label} must be a JSON object.")
        return payload

    def _atomic_json_write(self, target: Path, payload: dict[str, object]) -> None:
        target.parent.mkdir(parents=True, exist_ok=True)
        data = (json.dumps(payload, sort_keys=True) + "\n").encode("utf-8")
        fd, temp_name = tempfile.mkstemp(prefix=f".{target.name}.", suffix=".tmp", dir=target.parent)
        temp_path = Path(temp_name)
        try:
            with os.fdopen(fd, "wb") as handle:
                handle.write(data)
                handle.flush()
                os.fsync(handle.fileno())
            _harden(temp_path, 0o600)
            os.replace(temp_path, target)
            _harden(target, 0o600)
        finally:
            if temp_path.exists():
                temp_path.unlink()


def _empty_launch_route() -> CodexLaunchRoute:
    return CodexLaunchRoute(
        prepared=False,
        selection_mode=None,
        account_id=None,
        account_label=None,
        account_email=None,
        plan_type=None,
        effective_remaining_percent=None,
        primary_remaining_percent=None,
        secondary_remaining_percent=None,
        monthly_remaining_percent=None,
        limiting_remaining_credits=None,
        sampled_at=None,
        prepared_at=None,
        revision=0,
    )


def _valid_launch_route(route: CodexLaunchRoute) -> bool:
    if not isinstance(route.prepared, bool):
        return False
    if not isinstance(route.revision, int) or isinstance(route.revision, bool) or route.revision < 0:
        return False
    if not route.prepared:
        return route == _empty_launch_route()
    if (
        route.selection_mode not in {"auto", "manual"}
        or not isinstance(route.account_id, str)
        or not route.account_id.strip()
        or not isinstance(route.account_label, str)
        or not isinstance(route.account_email, str)
        or not isinstance(route.plan_type, str)
        or not isinstance(route.sampled_at, str)
        or not isinstance(route.prepared_at, str)
    ):
        return False
    percent_values = (
        route.effective_remaining_percent,
        route.primary_remaining_percent,
        route.secondary_remaining_percent,
        route.monthly_remaining_percent,
    )
    for value in percent_values:
        if value is not None and (
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not isfinite(value)
            or value < 0
            or value > 100
        ):
            return False
    credits = route.limiting_remaining_credits
    return credits is None or (
        not isinstance(credits, bool)
        and isinstance(credits, (int, float))
        and isfinite(credits)
        and credits >= 0
    )


def _normalize_endpoint(endpoint: str) -> str:
    candidate = endpoint.strip()
    try:
        parsed = urlsplit(candidate)
        port = parsed.port
    except ValueError as exc:
        raise CodexIntegrationError("The local OpenHUB endpoint is invalid.") from exc
    if parsed.scheme != "http" or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise CodexIntegrationError("Managed launch requires a plain HTTP loopback endpoint without credentials.")
    if parsed.path not in {"", "/"} or parsed.hostname is None or port is None:
        raise CodexIntegrationError("Managed launch requires a loopback host and explicit port.")
    try:
        address = ipaddress.ip_address(parsed.hostname)
    except ValueError as exc:
        raise CodexIntegrationError("Managed launch accepts only a numeric loopback address.") from exc
    if not address.is_loopback:
        raise CodexIntegrationError("Managed launch rejects non-loopback endpoints.")
    host = f"[{address.compressed}]" if address.version == 6 else address.compressed
    return f"http://{host}:{port}"


def _utc_now() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def _harden(path: Path, mode: int) -> None:
    try:
        os.chmod(path, mode)
    except OSError:
        pass


@lru_cache(maxsize=1)
def get_codex_integration_service() -> CodexIntegrationService:
    return CodexIntegrationService()
