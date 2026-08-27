<!-- GENERATED — edit scripts/generate_settings_reference.py, not this file. -->

# Settings Reference

**GENERATED** — edit `scripts/generate_settings_reference.py`, not this file.
Regenerate with `uv run python scripts/generate_settings_reference.py`;
`tests/unit/test_settings_reference.py` fails when this page drifts from
`app/core/config/settings.py`.

openhub currently exposes 117 settings. Every setting is an environment
variable with the `OPENHUB_` prefix (process environment or `.env` /
`.env.local` next to the process). All defaults work with zero configuration —
start from [Configuration](../configuration.md) for the handful that matter,
and treat everything else as advanced operational tunables.

## `PORT` (special case, no prefix)

The listen port (default `2455`) is read from the bare `PORT` process
environment variable, not a `OPENHUB_*` setting, and applies to host
(uvx/local) runs only — env files map only prefixed variables. In Docker the
container always listens on 2455 (the entrypoint pins `--port 2455`); change
the host side of the compose `ports` mapping instead.

## Core

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_DATA_DIR` | `Path` | `~/.openhub` (host) / `/var/lib/openhub` (container) |

## Database

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_DATABASE_ALEMBIC_AUTO_REMAP_ENABLED` | `bool` | `True` |
| `OPENHUB_DATABASE_MAX_OVERFLOW` | `int` | `10` |
| `OPENHUB_DATABASE_MIGRATE_ON_STARTUP` | `bool` | `True` |
| `OPENHUB_DATABASE_MIGRATION_LOCK_TIMEOUT_SECONDS` | `float` | `300.0` |
| `OPENHUB_DATABASE_MIGRATIONS_FAIL_FAST` | `bool` | `True` |
| `OPENHUB_DATABASE_POOL_SIZE` | `int` | `15` |
| `OPENHUB_DATABASE_SQLITE_PRE_MIGRATE_BACKUP_ENABLED` | `bool` | `True` |
| `OPENHUB_DATABASE_SQLITE_PRE_MIGRATE_BACKUP_MAX_FILES` | `int` | `5` |
| `OPENHUB_DATABASE_SQLITE_STARTUP_CHECK_MODE` | `'quick' \| 'full' \| 'off'` | `'quick'` |
| `OPENHUB_DATABASE_URL` | `str` | `sqlite+aiosqlite:///<data_dir>/store.db` |

## Encryption

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_ENCRYPTION_KEY_FILE` | `Path` | `<data_dir>/encryption.key` |
| `OPENHUB_ENCRYPTION_KEY_FINGERPRINT_MODE` | `'enforce' \| 'warn' \| 'off'` | `'enforce'` |

## Upstream transport

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_UPSTREAM_BASE_URL` | `str` | `'https://chatgpt.com/backend-api'` |
| `OPENHUB_UPSTREAM_COMPACT_TIMEOUT_SECONDS` | `float \| None` | `None` |
| `OPENHUB_UPSTREAM_CONNECT_TIMEOUT_SECONDS` | `float` | `8.0` |
| `OPENHUB_UPSTREAM_RESPONSE_CREATE_MAX_BYTES` | `int` | `15728640` |
| `OPENHUB_UPSTREAM_ROUTE_CACHE_TTL_SECONDS` | `float` | `60.0` |
| `OPENHUB_UPSTREAM_STREAM_TRANSPORT` | `'http' \| 'websocket' \| 'auto'` | `'auto'` |
| `OPENHUB_UPSTREAM_WEBSOCKET_TRUST_ENV` | `bool` | auto-detected from outbound proxy env vars |

## HTTP & streaming

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_COMPACT_REQUEST_BUDGET_SECONDS` | `float` | `180.0` |
| `OPENHUB_HTTP_CONNECTOR_LIMIT` | `int` | `100` |
| `OPENHUB_HTTP_CONNECTOR_LIMIT_PER_HOST` | `int` | `50` |
| `OPENHUB_HTTP_DOWNSTREAM_TRANSPORT_POLICY` | `'smart' \| 'always_http' \| 'always_websocket' \| 'pinned'` | `'smart'` |
| `OPENHUB_HTTP_RESPONSES_STREAM_REQUEST_BUDGET_SECONDS` | `float` | `7200.0` |
| `OPENHUB_MAX_DECOMPRESSED_BODY_BYTES` | `int` | `33554432` |
| `OPENHUB_MAX_DECOMPRESSED_RESPONSES_BODY_BYTES` | `int` | `134217728` |
| `OPENHUB_MAX_SSE_EVENT_BYTES` | `int` | `16777216` |
| `OPENHUB_SSE_KEEPALIVE_INTERVAL_SECONDS` | `float` | `10.0` |
| `OPENHUB_STREAM_IDLE_TIMEOUT_SECONDS` | `float` | `7200.0` |
| `OPENHUB_TRANSCRIPTION_REQUEST_BUDGET_SECONDS` | `float` | `120.0` |

## HTTP Responses session bridge

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_ADVERTISE_BASE_URL` | `str \| None` | `None` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_IDLE_TTL_SECONDS` | `float` | `900.0` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_ENABLED` | `bool` | `False` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_ENABLED` | `bool` | `True` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_GATEWAY_SAFE_MODE` | `bool` | `False` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_IDLE_TTL_SECONDS` | `float` | `120.0` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_INSTANCE_ID` | `str` | process hostname |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_INSTANCE_RING` | `list[str]` | `[]` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_MAX_SESSIONS` | `int` | `256` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_QUEUE_LIMIT` | `int` | `8` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_REQUEST_BUDGET_SECONDS` | `float` | `7200.0` |
| `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_STUCK_GATE_RETIRE_AFTER_SECONDS` | `float` | `300.0` |

## Proxy admission & account caps

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_PROXY_ACCOUNT_CAP_PARTITION_SCALE_DOWN_SECONDS` | `int` | `60` |
| `OPENHUB_PROXY_ACCOUNT_CAPS_SCOPE` | `'partitioned' \| 'replica'` | `'partitioned'` |
| `OPENHUB_PROXY_ACCOUNT_INFLIGHT_PENALTY_PCT` | `float` | `2.5` |
| `OPENHUB_PROXY_ACCOUNT_LEASE_TOKEN_WEIGHT` | `float` | `1.0` |
| `OPENHUB_PROXY_ACCOUNT_LEASE_TTL_SECONDS` | `float` | `900.0` |
| `OPENHUB_PROXY_ACCOUNT_RESPONSE_CREATE_LIMIT` | `int` | `4` |
| `OPENHUB_PROXY_ACCOUNT_STREAM_LIMIT` | `int` | `8` |
| `OPENHUB_PROXY_ACCOUNT_STREAM_RECOVERY_RESERVE` | `int` | `1` |
| `OPENHUB_PROXY_ADMISSION_WAIT_TIMEOUT_SECONDS` | `float` | `10.0` |
| `OPENHUB_PROXY_COMPACT_RESPONSE_CREATE_LIMIT` | `int` | `64` |
| `OPENHUB_PROXY_DOWNSTREAM_WEBSOCKET_IDLE_TIMEOUT_SECONDS` | `float` | `120.0` |
| `OPENHUB_PROXY_REFRESH_FAILURE_COOLDOWN_SECONDS` | `float` | `5.0` |
| `OPENHUB_PROXY_REQUEST_BUDGET_SECONDS` | `float` | `600.0` |
| `OPENHUB_PROXY_RESPONSE_CREATE_LIMIT` | `int` | `256` |
| `OPENHUB_PROXY_TOKEN_REFRESH_LIMIT` | `int` | `64` |
| `OPENHUB_PROXY_UNAUTHENTICATED_CLIENT_CIDRS` | `list[str]` | `[]` |
| `OPENHUB_PROXY_UPSTREAM_WEBSOCKET_CONNECT_LIMIT` | `int` | `128` |

## OAuth

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_OAUTH_CALLBACK_HOST` | `str` | `127.0.0.1` (host) / `0.0.0.0` (container) |
| `OPENHUB_OAUTH_TIMEOUT_SECONDS` | `float` | `30.0` |

## Token refresh

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_AUTH_GUARDIAN_ENABLED` | `bool` | `False` |
| `OPENHUB_TOKEN_REFRESH_CLAIM_TTL_SECONDS` | `float` | `30.0` |
| `OPENHUB_TOKEN_REFRESH_INTERVAL_DAYS` | `int` | `8` |
| `OPENHUB_TOKEN_REFRESH_TIMEOUT_SECONDS` | `float` | `8.0` |

## Usage & retention

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_LIVE_USAGE_INGESTION_ENABLED` | `bool` | `True` |
| `OPENHUB_RATE_LIMIT_RESET_CREDITS_REFRESH_INTERVAL_SECONDS` | `int` | `60` |
| `OPENHUB_REQUEST_LOG_RETENTION_DAYS` | `int` | `0` |
| `OPENHUB_USAGE_FETCH_MAX_RETRIES` | `int` | `2` |
| `OPENHUB_USAGE_FETCH_TIMEOUT_SECONDS` | `float` | `10.0` |
| `OPENHUB_USAGE_HISTORY_RETENTION_DAYS` | `int` | `0` |
| `OPENHUB_USAGE_REFRESH_AUTH_FAILURE_COOLDOWN_SECONDS` | `float` | `300.0` |
| `OPENHUB_USAGE_REFRESH_ENABLED` | `bool` | `True` |
| `OPENHUB_USAGE_REFRESH_INTERVAL_SECONDS` | `int` | `60` |
| `OPENHUB_USAGE_REFRESH_MAX_CONCURRENCY` | `int` | `4` |

## Prompt caching & affinity

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_OPENAI_CACHE_AFFINITY_MAX_AGE_SECONDS` | `int` | `1800` |
| `OPENHUB_OPENAI_PROMPT_CACHE_KEY_DERIVATION_ENABLED` | `bool` | `True` |

## Images

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_IMAGE_INLINE_ALLOWED_HOSTS` | `list[str]` | `[]` |
| `OPENHUB_IMAGE_INLINE_FETCH_ENABLED` | `bool` | `True` |
| `OPENHUB_IMAGES_DEFAULT_MODEL` | `str` | `'gpt-image-2'` |

## Model registry

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_MODEL_CONTEXT_WINDOW_OVERRIDES` | `dict[str, int]` | `{}` |
| `OPENHUB_MODEL_REGISTRY_CLIENT_VERSION` | `str` | `'0.144.0'` |
| `OPENHUB_MODEL_REGISTRY_ENABLED` | `bool` | `True` |
| `OPENHUB_MODEL_REGISTRY_SNAPSHOT_MAX_AGE_SECONDS` | `int` | `86400` |

## Firewall

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_FIREWALL_IP_CACHE_TTL_SECONDS` | `int` | `30` |
| `OPENHUB_FIREWALL_TRUST_PROXY_HEADERS` | `bool` | `False` |
| `OPENHUB_FIREWALL_TRUSTED_PROXY_CIDRS` | `list[str]` | `['127.0.0.1/32', '::1/128']` |

## Dashboard

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_DASHBOARD_AUTH_MODE` | `'standard' \| 'trusted_header' \| 'disabled'` | `'standard'` |
| `OPENHUB_DASHBOARD_AUTH_PROXY_HEADER` | `str` | `'Remote-User'` |
| `OPENHUB_DASHBOARD_BOOTSTRAP_TOKEN` | `str \| None` | `None` |
| `OPENHUB_DASHBOARD_TRUST_LOOPBACK_HOST_HEADER_FOR_LONG_SESSIONS` | `bool` | `False` |

## Conversation archive

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_CONVERSATION_ARCHIVE_DIR` | `Path` | `<data_dir>/conversation-archive` |
| `OPENHUB_CONVERSATION_ARCHIVE_ENABLED` | `bool` | `False` |
| `OPENHUB_CONVERSATION_ARCHIVE_QUEUE_MAX_BYTES` | `int` | `268435456` |

## Schedulers

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_AUTOMATIONS_SCHEDULER_ENABLED` | `bool` | `True` |
| `OPENHUB_QUOTA_PLANNER_SCHEDULER_ENABLED` | `bool` | `True` |
| `OPENHUB_STICKY_SESSION_CLEANUP_ENABLED` | `bool` | `True` |

## Multi-replica

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_LEADER_ELECTION_ENABLED` | `bool` | `True` |
| `OPENHUB_LEADER_ELECTION_TTL_SECONDS` | `int` | `60` |
| `OPENHUB_WORKERS_PER_INSTANCE` | `int` | `1` |

## Observability

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_LOG_FORMAT` | `str` | `'text'` |
| `OPENHUB_METRICS_ENABLED` | `bool` | `False` |
| `OPENHUB_METRICS_PORT` | `int` | `9090` |
| `OPENHUB_OTEL_ENABLED` | `bool` | `False` |
| `OPENHUB_OTEL_EXPORTER_ENDPOINT` | `str` | `''` |
| `OPENHUB_TRACE` | `str` | `''` |

## Resilience & load shedding

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_BACKPRESSURE_MAX_CONCURRENT_REQUESTS` | `int` | `0` |
| `OPENHUB_BULKHEAD_DASHBOARD_LIMIT` | `int` | `50` |
| `OPENHUB_BULKHEAD_PROXY_LIMIT` | `int` | `512` |
| `OPENHUB_CIRCUIT_BREAKER_ENABLED` | `bool` | `False` |
| `OPENHUB_DETERMINISTIC_FAILOVER_ENABLED` | `bool` | `True` |
| `OPENHUB_MEMORY_REJECT_THRESHOLD_MB` | `int` | `0` |
| `OPENHUB_SHUTDOWN_DRAIN_TIMEOUT_SECONDS` | `int` | `30` |
| `OPENHUB_SOFT_DRAIN_ENABLED` | `bool` | `True` |

## Other

| Environment variable | Type | Default |
| --- | --- | --- |
| `OPENHUB_NATIVE_FIXTURE_MODE` | `bool` | `False` |
| `OPENHUB_WARMUP_MODEL` | `str` | `'gpt-5.4-mini'` |

## Removed / deprecated

Deprecated env aliases (still functional for one release; the dashboard
runtime value wins when set):

- `OPENHUB_REQUEST_LOG_RETENTION_DAYS`
- `OPENHUB_USAGE_HISTORY_RETENTION_DAYS`

Removed settings (ignored; values are now fixed — see PRINCIPLES.md P2 /
issue [#1340](https://github.com/k1tvkli2003/OpenHUB/issues/1340)):

- `OPENHUB_AUTH_BASE_URL`
- `OPENHUB_OAUTH_CLIENT_ID`
- `OPENHUB_OAUTH_ORIGINATOR`
- `OPENHUB_OAUTH_SCOPE`
- `OPENHUB_OAUTH_REDIRECT_URI`
- `OPENHUB_OAUTH_CALLBACK_PORT`
- `OPENHUB_AUTH_GUARDIAN_INTERVAL_SECONDS`
- `OPENHUB_AUTH_GUARDIAN_MAX_REFRESH_AGE_SECONDS`
- `OPENHUB_AUTH_GUARDIAN_BATCH_SIZE`
- `OPENHUB_AUTH_GUARDIAN_CONCURRENCY`
- `OPENHUB_AUTH_GUARDIAN_JITTER_SECONDS`
- `OPENHUB_AUTH_GUARDIAN_FAILURE_BACKOFF_BASE_SECONDS`
- `OPENHUB_AUTH_GUARDIAN_FAILURE_BACKOFF_MAX_SECONDS`
- `OPENHUB_LOG_PROXY_REQUEST_SHAPE`
- `OPENHUB_LOG_PROXY_REQUEST_SHAPE_RAW_CACHE_KEY`
- `OPENHUB_LOG_PROXY_REQUEST_PAYLOAD`
- `OPENHUB_LOG_PROXY_SERVICE_TIER_TRACE`
- `OPENHUB_LOG_UPSTREAM_REQUEST_SUMMARY`
- `OPENHUB_LOG_UPSTREAM_REQUEST_PAYLOAD`
- `OPENHUB_BULKHEAD_PROXY_HTTP_LIMIT`
- `OPENHUB_BULKHEAD_PROXY_WEBSOCKET_LIMIT`
- `OPENHUB_BULKHEAD_PROXY_COMPACT_LIMIT`
- `OPENHUB_TOKEN_REFRESH_CLAIM_WAIT_SECONDS`
- `OPENHUB_TOKEN_REFRESH_CLAIM_POLL_SECONDS`
- `OPENHUB_QUOTA_PLANNER_TICK_SECONDS`
- `OPENHUB_AUTOMATIONS_SCHEDULER_INTERVAL_SECONDS`
- `OPENHUB_MODEL_REGISTRY_REFRESH_INTERVAL_SECONDS`
- `OPENHUB_STICKY_SESSION_CLEANUP_INTERVAL_SECONDS`
- `OPENHUB_CODEX_FINGERPRINT_OS`
- `OPENHUB_CODEX_FINGERPRINT_ARCH`
- `OPENHUB_CODEX_FINGERPRINT_TERMINAL`
- `OPENHUB_LIVE_USAGE_WRITE_MIN_INTERVAL_SECONDS`
- `OPENHUB_LIVE_USAGE_QUEUE_SIZE`
- `OPENHUB_REQUEST_LOG_COUNT_CACHE_TTL_SECONDS`
- `OPENHUB_CIRCUIT_BREAKER_FAILURE_THRESHOLD`
- `OPENHUB_CIRCUIT_BREAKER_RECOVERY_TIMEOUT_SECONDS`
- `OPENHUB_MEMORY_WARNING_THRESHOLD_MB`
- `OPENHUB_IMAGES_HOST_MODEL`
- `OPENHUB_IMAGES_MAX_PARTIAL_IMAGES`
- `OPENHUB_DATABASE_BACKGROUND_POOL_SIZE`
- `OPENHUB_DATABASE_BACKGROUND_MAX_OVERFLOW`
- `OPENHUB_DATABASE_POOL_TIMEOUT_SECONDS`
- `OPENHUB_DATABASE_POOL_RECYCLE_SECONDS`
- `OPENHUB_DRAIN_PRIMARY_THRESHOLD_PCT`
- `OPENHUB_DRAIN_SECONDARY_THRESHOLD_PCT`
- `OPENHUB_DRAIN_ERROR_WINDOW_SECONDS`
- `OPENHUB_DRAIN_ERROR_COUNT_THRESHOLD`
- `OPENHUB_PROBE_QUIET_SECONDS`
- `OPENHUB_PROBE_SUCCESS_STREAK_REQUIRED`
- `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_CANARY_PERCENT`
- `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_ALLOW_API_KEY_IDS`
- `OPENHUB_HTTP_RESPONSES_SESSION_BRIDGE_CODEX_PREWARM_DENY_API_KEY_IDS`

---

*Specs: [user-documentation](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/user-documentation) · [deployment-installation](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/deployment-installation)*
