# Change: Count newly created runtime-task usage in Pulse windows

## Why

Pulse establishes a zero baseline when OpenHUB starts so historical task usage
does not appear as current traffic. The same rule is currently applied to a
task first created after startup, causing that task's entire first completed
turn to disappear from the one-minute, one-hour, and since-start counters.

## What Changes

- Establish the zero baseline once per available runtime rather than once per
  task forever.
- Count the current total of a task that first appears after its runtime has
  already been baselined.
- Keep a runtime that was unavailable at startup from backfilling historical
  tasks when it first becomes readable.
- Add focused regression coverage and a live Hermes-to-OpenHUB-to-Pulse probe.

## Impact

- Affected spec: `multi-runtime-control`
- Affected code: `app/modules/runtime_control/service.py`
- Affected tests: `tests/unit/test_runtime_control.py`
