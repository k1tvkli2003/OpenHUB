## Why

OpenHUB can route across a local fleet of fifteen accounts, but the proxy's
legacy per-request failover caps stop after two compact accounts or three
stream/WebSocket accounts. If those early candidates report a pre-visible quota
failure while a later eligible account is healthy, the client can still receive
an avoidable quota error.

## What Changes

- Let replay-safe, pre-visible failover traverse the whole current fifteen-account
  fleet, with a defensive cap of sixteen distinct account attempts.
- Apply the same bounded pool traversal to SSE, compact HTTP, and WebSocket
  transports.
- Preserve request deadlines, failed-account exclusion, file ownership,
  previous-response continuity, and the no-replay-after-visible-output rule.
- Add regressions that require a healthy account beyond the legacy attempt caps.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `responses-api-compat`

## Impact

- Affected code: proxy retry limits and transport failover tests.
- Affected behavior: replay-safe requests can reach a later healthy account
  instead of stopping after the first two or three quota failures.
- No schema, migration, dependency, credential, public request field, or Codex
  configuration change.
