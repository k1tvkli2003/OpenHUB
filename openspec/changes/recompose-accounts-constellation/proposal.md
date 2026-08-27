## Why

The Accounts screen currently spends most of its width on one permanently open
detail panel. That makes a 15-account pool slow to scan and hides the decisions
that matter most: which accounts are usable now, which data is fresh, and which
account OpenHUB will route next.

## What Changes

- Recompose Accounts as a compact constellation grouped into Ready now, Needs
  attention, and Offline or exhausted.
- Give every row a quota ring and a symbolic freshness state that distinguishes
  fresh, stale, not refreshed since this app launch, exhausted, and reauthentication.
- Show a live three-account Next route rail derived from the globally selected
  remaining-usage order.
- Replace the permanent wide detail split with a compact selected-account
  inspector while preserving launch, reauthentication, routing, pause, probe,
  reset-credit, alias, and delete actions.
- Preserve virtualization for large account pools and stack the route rail and
  inspector on narrow windows.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `account-quota-presentation`
- `frontend-architecture`

## Impact

- Affected code: native Windows Accounts page and app-session metadata.
- Affected behavior: presentation and action placement only; account ordering
  still uses the existing global remaining-usage setting.
- Data safety: no credential, Codex configuration, chat, database schema, or
  authentication-store mutation is introduced.
