## 1. Account quota reset presentation

- [x] 1.1 Add precise reset-countdown formatting with due-now and unknown states.
- [x] 1.2 Add one shared page-owned countdown clock without network refreshes.
- [x] 1.3 Render all reported windows in expanded rows and the nearest reset in compact and dense rows.
- [x] 1.4 Preserve exact reset timestamps in tooltips and accessibility semantics.
- [x] 1.5 Start account-usage refresh automatically after writable authenticated startup.

## 2. Stable Windows installation

- [x] 2.1 Replace timestamped installed package directories with a staged fixed App directory under Program Files.
- [x] 2.2 Retain one current package artifact in a fixed Release directory.
- [x] 2.3 Point desktop and Start Menu shortcuts at the stable installed executable and keep startup disabled.
- [x] 2.4 Remove superseded OpenHUB packages only after successful installation.

## 3. Verification

- [x] 3.1 Add formatter and widget regressions for reset countdowns and responsive layouts.
- [x] 3.1a Add a startup orchestration regression for automatic account refresh.
- [x] 3.2 Run Flutter formatting, static analysis, and native tests.
- [ ] 3.2a Run strict OpenSpec validation when the repository provides a working OpenSpec CLI.
- [x] 3.3 Build, install, launch, and smoke-test the fixed Program Files package.
- [x] 3.4 Verify shortcuts, release artifact, and absence of superseded installed packages.
