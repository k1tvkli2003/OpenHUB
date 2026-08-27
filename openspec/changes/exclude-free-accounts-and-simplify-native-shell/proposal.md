## Why

OpenHUB currently treats an active account with a reported `free` plan as a
normal routing candidate. That can place a Free account in Smart API, Auto
Route, manual Codex launch, sticky fallback, or a pinned route even though the
local product contract considers Free subscriptions unusable.

The native shell also gives a permanent account inspector and a separate
Overview destination more space than the operator's primary task: scanning and
acting on the full account pool.

## What Changes

- Make an explicitly Free subscription a hard routing exclusion across proxy
  selection and managed Codex launch selection, without pausing, deleting, or
  mutating the stored account.
- Present Free accounts in the native Accounts screen as unavailable and
  disable every manual launch affordance for them.
- Recompose Accounts as a list-first surface: one compact Next Route strip,
  full-height virtualized account rows, and row-owned management instead of a
  permanent bottom inspector.
- Remove Overview from top-level navigation and make Accounts the initial
  destination.
- Move live fleet capacity, routing projections, and request attribution into
  Traffic; keep aggregate analytics as a sibling Traffic view.
- Move Auto Route enable/disable and normal launch controls into Settings.

## Capabilities

### Modified Capabilities

- `account-routing`
- `account-quota-presentation`
- `frontend-architecture`

## Impact

- Affected code: canonical balancer eligibility, managed Codex launch
  selection, native navigation/controller loading, Accounts, Traffic, and
  Settings UI.
- Data safety: account rows, credentials, Codex config, auth, chats, sessions,
  and local databases are not rewritten by this change.
- Compatibility: unknown or unreported plan values retain their existing
  fail-open/fail-closed behavior; only an explicit Free-family plan is newly
  blocked.
