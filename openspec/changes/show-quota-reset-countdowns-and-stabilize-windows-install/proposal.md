## Why

Account rows expose remaining quota but hide when each quota window becomes
available again. Operators therefore have to open the inspector for every
account and still receive only a coarse relative time. The local Windows build
also installs into timestamped directories, which leaves stale packages and
shortcuts behind after repeated local releases.

## What Changes

- Add a prominent, live quota-reset countdown beside every account, showing all
  reported windows in the expanded row and the nearest reported reset in compact
  or dense layouts.
- Start a real account-usage refresh automatically after authenticated writable
  startup hydrates the initial cached account list.
- Preserve exact reset timestamps in tooltips and use explicit unknown/due-now
  states instead of inventing schedules.
- Install OpenHUB into one stable application directory under Program Files,
  preserve one current release artifact there, and make desktop/Start Menu
  shortcuts target the stable installed executable.
- Remove superseded OpenHUB application packages only after the new package has
  passed validation and completed its staged installation.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `account-quota-presentation`
- `deployment-installation`

## Impact

- Affected code: native Windows Accounts presentation and local Windows build,
  controller startup, install, launch, and shortcut scripts.
- Data safety: no credential, account, Codex configuration, chat, database, or
  authentication-store mutation.
- Network impact: countdown updates are local clock renders and trigger no API
  refresh.
