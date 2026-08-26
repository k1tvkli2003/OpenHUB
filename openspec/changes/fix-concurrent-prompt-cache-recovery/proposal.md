## Why

Concurrent OpenAI-compatible Responses requests can race while a recovery probe
transitions an account back to active. The winning CAS updates the database, but
the five-second account-selection cache can keep the previous row. A losing
request then retries the same stale snapshot until it returns `503/no_accounts`
even though healthy accounts remain.

## What Changes

- Invalidate cached selection inputs after either a committed state transition
  or a CAS miss so bounded retries reload the current pool.
- Preserve fallback to the remaining healthy pool for soft prompt-cache traffic.
- Preserve hard continuity ownership and the one-probe-at-a-time invariant.
- Add a regression covering concurrent same-key prompt-cache selections.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `sticky-session-operations`

## Impact

- Affected code: sticky account selection and its concurrency tests.
- Affected behavior: unrelated first-turn Responses calls no longer receive a
  false global pool-exhaustion error during recovery-probe contention.
- No schema, migration, setting, dependency, credential, or public request field
  changes.
