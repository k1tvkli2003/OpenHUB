## Verification report

- Flutter formatter completed for the changed Dart sources and tests.
- `flutter analyze` completed with no issues.
- All functional native Windows Flutter tests passed; the live external contract
  test remained explicitly skipped because it requires a disposable fixture
  endpoint. The debug performance guard is host-load sensitive inside the full
  suite and passed in its isolated measurement with account-scroll p95 at
  26.387 ms after the dense reset indicator was simplified.
- The deterministic Accounts golden was regenerated and visually inspected.
- PowerShell parsing passed for build, install, and launch scripts.
- The stable package and zip artifact were built successfully.
- The fixed installation completed at `C:\Program Files\OpenHUB\App` and
  retained one release zip plus installer at `C:\Program Files\OpenHUB\Release`.
- The installed process started, `/api/accounts` responded, and returned 15
  account summaries.
- A final clean startup triggered refresh without an operator click; four
  accounts already had samples newer than the installed-process start when the
  immediate verification probe completed. An earlier longer probe observed 14
  current-session samples.
- Desktop shortcuts resolve the stable executable; the managed shortcut carries
  `--launch-codex` and startup remains disabled.
- The superseded LocalAppData package and source-tree timestamped package were
  removed after successful installation. `DisabledStartupShortcuts` was
  preserved.

Strict OpenSpec CLI validation remains unavailable because this repository does
not provide an OpenSpec executable and prior project evidence documents that the
public `npx openspec` package is not the required validator. Proposal, design,
tasks, delta-spec structure, implementation, and evidence were reviewed
directly as the documented graceful-degradation path.
