## 1. Routing eligibility

- [x] 1.1 Add one canonical Free-plan predicate shared by routing surfaces.
- [x] 1.2 Exclude Free-family plans in canonical proxy account selection,
      including sticky, pinned, failover, and single-account paths.
- [x] 1.3 Exclude Free-family plans from automatic and manual managed Codex
      launch selection with a stable reason.
- [x] 1.4 Add regressions proving a higher-quota Free account never beats an
      eligible paid account and a Free-only pool returns no candidate.

## 2. Native information architecture

- [x] 2.1 Remove Overview from the destination model and start on Accounts.
- [x] 2.2 Make Traffic own live fleet/request attribution and aggregate report
      views, preserving refresh and filter behavior.
- [x] 2.3 Make Settings own Auto Route enable/disable and normal launch controls.

## 3. Accounts list-first composition

- [x] 3.1 Classify Free accounts as unavailable, explain the exclusion, and
      disable all row/detail launch actions.
- [x] 3.2 Replace side-rail and permanent bottom inspector layouts with a
      compact horizontal Next Route strip and full-height virtualized list.
- [x] 3.3 Put management on each account row while preserving every existing
      account action in the management dialog.
- [x] 3.4 Surface relocated account readiness and Free-exclusion counts in the
      compact Accounts header.

## 4. Verification

- [x] 4.1 Run focused Python routing and Codex launch tests.
- [x] 4.2 Run Flutter formatting, analysis, widget, navigation, performance, and
      golden tests.
- [ ] 4.3 Capture and visually inspect the real Accounts and Traffic runtime at
      representative desktop sizes.
- [x] 4.4 Build, package, install, and launch the elevated Windows artifact;
      verify startup remains disabled and Git remotes remain absent.
- [ ] 4.5 Run strict OpenSpec validation when the CLI is available locally.
