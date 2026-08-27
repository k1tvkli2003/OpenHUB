# Context: reduce-settings-surface-phase-2

## Rationale

Phase 2 of issue #1340, following the same selection rule as phase 1: every
removed field keeps its exact previous default as the new fixed value, and
the only behavioral seam (the removed-settings warning) is additive. Unlike
phase 1, three of this batch's env names were rendered by the Helm chart
(`config.circuitBreakerFailureThreshold`,
`config.circuitBreakerRecoveryTimeoutSeconds`,
`config.stickySessionCleanupIntervalSeconds`); the chart values are removed
in the same change so a default install does not trip its own removal
warning. Chart users who overrode them fall back to the identical fixed
constants.

Capability choice mirrors phase 1: `deployment-installation` owns the
operator env-var contract at settings-load time, so the phase-2 fixed-values
requirement is added there alongside the phase-1 requirement.

## Removed fields (env names)

Scheduler cadences (now constants next to their builders):

- `OPENHUB_QUOTA_PLANNER_TICK_SECONDS` (fixed: 300; the previous
  `max(60, ...)` floor is moot for a fixed 300 and was dropped)
- `OPENHUB_AUTOMATIONS_SCHEDULER_INTERVAL_SECONDS` (fixed: 30)
- `OPENHUB_MODEL_REGISTRY_REFRESH_INTERVAL_SECONDS` (fixed: 300)
- `OPENHUB_STICKY_SESSION_CLEANUP_INTERVAL_SECONDS` (fixed: 300)

Codex client fingerprint (now constants in `app/core/clients/proxy.py`;
maintained in lockstep with `model_registry_client_version` bumps):

- `OPENHUB_CODEX_FINGERPRINT_OS` (fixed: `Mac OS 26.5.0`)
- `OPENHUB_CODEX_FINGERPRINT_ARCH` (fixed: `arm64`)
- `OPENHUB_CODEX_FINGERPRINT_TERMINAL` (fixed: `iTerm.app/3.6.10`)

Live-usage write coalescing (now constants in
`app/modules/usage/live_ingest.py`):

- `OPENHUB_LIVE_USAGE_WRITE_MIN_INTERVAL_SECONDS` (fixed: 5.0)
- `OPENHUB_LIVE_USAGE_QUEUE_SIZE` (fixed: 512)

Request-log count cache (now a constant in
`app/modules/request_logs/repository.py`):

- `OPENHUB_REQUEST_LOG_COUNT_CACHE_TTL_SECONDS` (fixed: 30.0; the test
  suite patches the constant to 0 so listing totals stay exact per test)

Circuit-breaker tuning (now constants in
`app/core/resilience/circuit_breaker.py`):

- `OPENHUB_CIRCUIT_BREAKER_FAILURE_THRESHOLD` (fixed: 5)
- `OPENHUB_CIRCUIT_BREAKER_RECOVERY_TIMEOUT_SECONDS` (fixed: 60)

Memory thresholds (warning now derived in
`app/core/resilience/memory_monitor.py`):

- `OPENHUB_MEMORY_WARNING_THRESHOLD_MB` (derived: 80% of
  `memory_reject_threshold_mb`)

Images internals:

- `OPENHUB_IMAGES_HOST_MODEL` (fixed: `gpt-5.5`, a constant in
  `app/modules/proxy/api.py`)
- `OPENHUB_IMAGES_MAX_PARTIAL_IMAGES` (fixed: 3, a constant in
  `app/core/openai/images.py`)

Kept deliberately: `OPENHUB_QUOTA_PLANNER_SCHEDULER_ENABLED`,
`OPENHUB_AUTOMATIONS_SCHEDULER_ENABLED`, `OPENHUB_MODEL_REGISTRY_ENABLED`,
`OPENHUB_STICKY_SESSION_CLEANUP_ENABLED`,
`OPENHUB_LIVE_USAGE_INGESTION_ENABLED`, `OPENHUB_CIRCUIT_BREAKER_ENABLED`
(each subsystem keeps exactly one switch);
`OPENHUB_MODEL_REGISTRY_CLIENT_VERSION` (degraded-startup catalog floor
with a documented minimum, not merely fingerprint cosmetics);
`OPENHUB_MEMORY_REJECT_THRESHOLD_MB` (the one genuine deployment decision
in the memory guard — it depends on the host's memory size);
`OPENHUB_IMAGES_DEFAULT_MODEL` (public API contract for clients that omit
`model`).

## Memory-threshold decision

`memory_warning_threshold_mb` and `memory_reject_threshold_mb` were two
independent knobs for one mechanism: the bulkhead middleware logs a warning
when RSS crosses the warning level and rejects with 503 when it crosses the
reject level. The warning has no meaning on its own — it exists to announce
that the reject threshold is being approached — so it is not an independent
operator decision. Phase 2 keeps `memory_reject_threshold_mb` (0 = off, the
default) and derives the warning level as a fixed 80% of it. With the
default of 0 both thresholds remain disabled, so zero-config behavior is
unchanged; deployments that set only the reject threshold now get an early
warning for free. The only lost configuration is a warning-only setup with
no reject threshold, which rejected nothing and merely logged — an
observability half-measure the log stream covers anyway.

## Images host model decision

The audit suggested deriving the images host model from the model registry,
but the registry has no "default Responses model" concept — `gpt-5.5` is
one of several bootstrap catalog entries. Inventing registry plumbing for
one internal default would add more surface than the setting it removes, so
the host model is a documented module constant (`_IMAGES_HOST_MODEL` in
`app/modules/proxy/api.py`) that tracks the catalog's stable `gpt-5.5` slug
and changes only with catalog maintenance. It is never echoed to clients.

## Example

An operator running `OPENHUB_QUOTA_PLANNER_TICK_SECONDS=60` upgrades:
startup logs

```
removed setting(s) ignored: OPENHUB_QUOTA_PLANNER_TICK_SECONDS — values are now fixed; see PRINCIPLES.md P2 / issue #1340
```

and the planner ticks on the fixed five-minute cadence.

## Cross-change coordination

The active (unarchived) `cache-request-log-count` change originally specified
the count-cache TTL as a configurable setting with `0` disabling the cache.
Its delta spec and tasks were updated in this change to the fixed-constant
reality so a later archive cannot reintroduce a requirement the code no
longer satisfies.
