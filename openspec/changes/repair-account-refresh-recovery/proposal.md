## Why

OpenHUB can currently classify a generic usage-endpoint HTTP 404 as a
permanent account deactivation. Once that happens, normal refresh skips the
row forever, so both startup refresh and the Accounts refresh action become a
no-op even after the upstream endpoint is healthy again.

## What Changes

- Treat only explicit permanent account signals as deactivation evidence; a
  bare usage HTTP 404 remains a retryable refresh failure.
- Let refresh retry the exact legacy rows that OpenHUB previously deactivated
  with the generic `Usage fetch failed (404)` reason.
- Recover those legacy rows atomically from fresh quota evidence into
  `active`, `rate_limited`, or `quota_exceeded` without reviving genuinely
  deactivated or re-authentication-required accounts.
- Make entering the Accounts destination request a bounded live usage refresh,
  while retaining cached-first rendering and single-flight protection.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `usage-refresh-policy`
- `frontend-architecture`

## Impact

- Affected code: usage refresh classification/recovery and native Windows
  Accounts destination loading.
- Affected data: only legacy rows carrying the exact generic HTTP 404
  deactivation reason may be recovered; no schema migration is required.
- Compatibility: permanent deactivation codes/messages and
  `reauth_required` remain fail-closed.
