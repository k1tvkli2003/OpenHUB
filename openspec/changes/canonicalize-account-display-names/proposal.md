## Why

Account surfaces currently fall back to full email addresses, which makes a
15-account pool noisy and inconsistent with the compact OpenHUB interface.

## What Changes

- Derive automatic account names from the email local part.
- Remove trailing digits, turn common separators into spaces, and uppercase
  the first character.
- Preserve explicit operator aliases as exact overrides.
- Reuse the same label in native account-cost analytics instead of rendering
  raw email addresses.
- Add an Accounts-page subscription filter for all, paid, and free plans.

## Capabilities

### Modified Capabilities

- `frontend-architecture`

## Impact

- Affected code: account summary mapping and native API-key analytics labels.
- Data safety: stored emails and aliases are not changed; this is display-only.
