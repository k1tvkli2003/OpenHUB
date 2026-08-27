"""Tests for the OPENHUB_TRACE channels and the removed-settings warning.

Introduced by the ``reduce-settings-surface-phase-1`` change (issue #1340).
"""

from __future__ import annotations

import logging

import pytest

from app.core.config.settings import _REMOVED_SETTINGS, Settings, warn_removed_settings

pytestmark = pytest.mark.unit


def test_trace_defaults_to_no_channels():
    settings = Settings()
    assert settings.trace == ""
    assert settings.trace_channels == frozenset()


def test_trace_parses_comma_separated_channels(monkeypatch):
    monkeypatch.setenv("OPENHUB_TRACE", "shape,upstream_payload")
    settings = Settings()
    assert settings.trace_channels == frozenset({"shape", "upstream_payload"})


def test_trace_normalizes_whitespace_case_and_empty_entries():
    settings = Settings(trace=" Shape , SERVICE_TIER ,, payload ,")
    assert settings.trace_channels == frozenset({"shape", "service_tier", "payload"})


def test_trace_channels_is_cached_per_settings_instance():
    settings = Settings(trace="shape")
    assert settings.trace_channels is settings.trace_channels


def test_removed_log_settings_env_vars_are_ignored(monkeypatch):
    monkeypatch.setenv("OPENHUB_LOG_PROXY_REQUEST_SHAPE", "true")
    monkeypatch.setenv("OPENHUB_LOG_UPSTREAM_REQUEST_PAYLOAD", "true")
    settings = Settings()
    assert settings.trace_channels == frozenset()
    assert not hasattr(settings, "log_proxy_request_shape")


def test_warn_removed_settings_logs_one_warning_listing_found_names(caplog):
    environ = {
        "OPENHUB_AUTH_BASE_URL": "https://auth.example.test",
        "OPENHUB_TOKEN_REFRESH_CLAIM_WAIT_SECONDS": "9.0",
        "OPENHUB_TRACE": "shape",  # current setting, never reported
        "UNRELATED": "1",
    }
    with caplog.at_level(logging.WARNING, logger="app.core.config.settings"):
        found = warn_removed_settings(environ)

    assert found == ["OPENHUB_AUTH_BASE_URL", "OPENHUB_TOKEN_REFRESH_CLAIM_WAIT_SECONDS"]
    warnings = [record for record in caplog.records if record.levelno == logging.WARNING]
    assert len(warnings) == 1
    message = warnings[0].getMessage()
    assert "OPENHUB_AUTH_BASE_URL" in message
    assert "OPENHUB_TOKEN_REFRESH_CLAIM_WAIT_SECONDS" in message
    assert "PRINCIPLES.md P2" in message
    assert "#1340" in message
    # Values must never be logged.
    assert "auth.example.test" not in message
    assert "9.0" not in message


def test_warn_removed_settings_is_silent_when_nothing_is_set(caplog):
    with caplog.at_level(logging.WARNING, logger="app.core.config.settings"):
        found = warn_removed_settings({"OPENHUB_TRACE": "shape"})

    assert found == []
    assert not [record for record in caplog.records if record.levelno >= logging.WARNING]


def test_warn_removed_settings_scans_env_files(tmp_path, monkeypatch, caplog):
    env_file = tmp_path / ".env.local"
    env_file.write_text("OPENHUB_BULKHEAD_PROXY_HTTP_LIMIT=64\n", encoding="utf-8")
    monkeypatch.setattr("app.core.config.settings.ENV_FILES", (tmp_path / ".env", env_file))
    monkeypatch.delenv("OPENHUB_BULKHEAD_PROXY_HTTP_LIMIT", raising=False)

    with caplog.at_level(logging.WARNING, logger="app.core.config.settings"):
        found = warn_removed_settings()

    assert found == ["OPENHUB_BULKHEAD_PROXY_HTTP_LIMIT"]
    assert "64" not in caplog.text


def test_removed_settings_tuple_covers_all_five_groups():
    assert len(_REMOVED_SETTINGS) == 52
    assert all(name.startswith("OPENHUB_") for name in _REMOVED_SETTINGS)
    assert len(set(_REMOVED_SETTINGS)) == len(_REMOVED_SETTINGS)


def test_phase_2_removed_settings_are_listed_and_ignored(monkeypatch):
    phase_2_names = (
        "OPENHUB_QUOTA_PLANNER_TICK_SECONDS",
        "OPENHUB_AUTOMATIONS_SCHEDULER_INTERVAL_SECONDS",
        "OPENHUB_MODEL_REGISTRY_REFRESH_INTERVAL_SECONDS",
        "OPENHUB_STICKY_SESSION_CLEANUP_INTERVAL_SECONDS",
        "OPENHUB_CODEX_FINGERPRINT_OS",
        "OPENHUB_CODEX_FINGERPRINT_ARCH",
        "OPENHUB_CODEX_FINGERPRINT_TERMINAL",
        "OPENHUB_LIVE_USAGE_WRITE_MIN_INTERVAL_SECONDS",
        "OPENHUB_LIVE_USAGE_QUEUE_SIZE",
        "OPENHUB_REQUEST_LOG_COUNT_CACHE_TTL_SECONDS",
        "OPENHUB_CIRCUIT_BREAKER_FAILURE_THRESHOLD",
        "OPENHUB_CIRCUIT_BREAKER_RECOVERY_TIMEOUT_SECONDS",
        "OPENHUB_MEMORY_WARNING_THRESHOLD_MB",
        "OPENHUB_IMAGES_HOST_MODEL",
        "OPENHUB_IMAGES_MAX_PARTIAL_IMAGES",
    )
    for name in phase_2_names:
        assert name in _REMOVED_SETTINGS

    monkeypatch.setenv("OPENHUB_QUOTA_PLANNER_TICK_SECONDS", "60")
    monkeypatch.setenv("OPENHUB_IMAGES_HOST_MODEL", "gpt-5.6")
    settings = Settings()
    assert not hasattr(settings, "quota_planner_tick_seconds")
    assert not hasattr(settings, "images_host_model")
    found = warn_removed_settings(
        {
            "OPENHUB_QUOTA_PLANNER_TICK_SECONDS": "60",
            "OPENHUB_IMAGES_HOST_MODEL": "gpt-5.6",
        }
    )
    assert found == [
        "OPENHUB_QUOTA_PLANNER_TICK_SECONDS",
        "OPENHUB_IMAGES_HOST_MODEL",
    ]


def test_phase_3_removed_settings_are_listed_and_ignored(monkeypatch):
    phase_3_names = (
        "OPENHUB_DATABASE_BACKGROUND_POOL_SIZE",
        "OPENHUB_DATABASE_BACKGROUND_MAX_OVERFLOW",
        "OPENHUB_DATABASE_POOL_TIMEOUT_SECONDS",
        "OPENHUB_DATABASE_POOL_RECYCLE_SECONDS",
        "OPENHUB_DRAIN_PRIMARY_THRESHOLD_PCT",
        "OPENHUB_DRAIN_SECONDARY_THRESHOLD_PCT",
        "OPENHUB_DRAIN_ERROR_WINDOW_SECONDS",
        "OPENHUB_DRAIN_ERROR_COUNT_THRESHOLD",
        "OPENHUB_PROBE_QUIET_SECONDS",
        "OPENHUB_PROBE_SUCCESS_STREAK_REQUIRED",
    )
    for name in phase_3_names:
        assert name in _REMOVED_SETTINGS

    monkeypatch.setenv("OPENHUB_DATABASE_POOL_RECYCLE_SECONDS", "600")
    monkeypatch.setenv("OPENHUB_DRAIN_PRIMARY_THRESHOLD_PCT", "75.0")
    settings = Settings()
    assert not hasattr(settings, "database_pool_recycle_seconds")
    assert not hasattr(settings, "drain_primary_threshold_pct")
    assert settings.database_pool_size == 15
    assert settings.soft_drain_enabled is True
    found = warn_removed_settings(
        {
            "OPENHUB_DATABASE_POOL_RECYCLE_SECONDS": "600",
            "OPENHUB_DRAIN_PRIMARY_THRESHOLD_PCT": "75.0",
        }
    )
    assert found == [
        "OPENHUB_DATABASE_POOL_RECYCLE_SECONDS",
        "OPENHUB_DRAIN_PRIMARY_THRESHOLD_PCT",
    ]


def test_phase_4_removed_settings_are_listed_and_ignored(monkeypatch):
    phase_4_names = (
        "OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_CANARY_PERCENT",
        "OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_ALLOW_API_KEY_IDS",
        "OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_DENY_API_KEY_IDS",
    )
    for name in phase_4_names:
        assert name in _REMOVED_SETTINGS

    monkeypatch.setenv("OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_CANARY_PERCENT", "25.0")
    monkeypatch.setenv("OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_ALLOW_API_KEY_IDS", "key-a,key-b")
    settings = Settings()
    assert not hasattr(settings, "http_responses_session_bridge_codex_prewarm_canary_percent")
    assert not hasattr(settings, "http_responses_session_bridge_codex_prewarm_allow_api_key_ids")
    assert not hasattr(settings, "http_responses_session_bridge_codex_prewarm_deny_api_key_ids")
    # The prewarm feature flag itself survives phase 4.
    assert settings.http_responses_session_bridge_codex_prewarm_enabled is False
    found = warn_removed_settings(
        {
            "OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_CANARY_PERCENT": "25.0",
            "OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_ALLOW_API_KEY_IDS": "key-a,key-b",
        }
    )
    assert found == [
        "OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_CANARY_PERCENT",
        "OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_ALLOW_API_KEY_IDS",
    ]
