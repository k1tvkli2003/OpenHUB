## Why

Account rows expose a vague quota connection state but hide when each account
was actually sampled. Credential refresh time is also absent from the visible
account workflow, making old or blocked data look current.

## What Changes

- Show the latest quota sample age on every account row.
- Show credential refresh separately so it is never confused with usage data.
- Provide exact local timestamps in the account detail and row tooltip.
- Keep freshness derived from existing read-only response fields; no credential,
  Codex configuration, or database migration is involved.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `account-quota-presentation`
- `frontend-architecture`

## Impact

- Affected code: native Windows account list and detail surface.
- Affected data: display-only `usageSampleAt` and `lastRefreshAt` fields already
  returned by the backend.
