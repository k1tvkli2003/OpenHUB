## Context

The account API already supplies primary, secondary, and monthly reset
timestamps. The Accounts page currently renders those timestamps only inside
the selected-account inspector. Local Windows packaging uses a timestamped
package directory and a pointer-based launcher under LocalAppData.

## Decisions

### One shared countdown clock

AccountsPage owns one minute-aligned clock notifier. Visible reset indicators
listen to that clock; no row owns a timer and no countdown tick performs a
network request or refreshes account state.

### Window-aware reset presentation

Expanded rows render every reported quota reset with short semantic labels
(`5H`, `7D`, `30D`). Narrow and dense rows render only the earliest reported
reset. Values use stable-width numerals and display `Due now` for elapsed reset
timestamps and `Not reported` when no reset timestamp exists. Tooltips retain
the exact local timestamp and accessible semantics include the reset state.

### Stable local installation

The installed application lives at `C:\Program Files\OpenHUB\App`; the current
validated package artifact lives at `C:\Program Files\OpenHUB\Release`. An
installer stages the new app under the same root, validates the staged files,
atomically swaps it into `App`, then recreates shortcuts to the stable
`OpenHUB.exe`. The previous `App` is removed only after the swap succeeds.

The source-tree build remains a staging artifact because writing compilation
outputs directly into Program Files would require the compiler toolchain to run
elevated. Installation copies the validated build into the fixed Program Files
layout and retains one release artifact there.

## Risks and mitigations

- A running executable can prevent replacement. The installer detects a running
  OpenHUB process and fails before mutation with an actionable message.
- Program Files requires elevation. The installer relaunches itself with the
  standard UAC boundary when needed.
- A failed staged copy could leave partial files. Staging uses a unique sibling
  directory and is removed on failure; the current App remains untouched.
