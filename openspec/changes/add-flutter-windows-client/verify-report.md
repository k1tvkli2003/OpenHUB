# Verification Report: add-flutter-windows-client

## Summary

| Dimension | Status |
| --- | --- |
| Completeness | 52/53 tasks complete; installed visual capture remains |
| Correctness | Managed launch, route trust, packaging, ordering, and elevation requirements covered by implementation and tests |
| Coherence | Implementation follows the single-backend, zero-Codex-mutation, process-scoped routing design |

## Evidence

- `flutter analyze`: no issues.
- Full Flutter suite: 72 passed, 1 live-fixture test intentionally skipped because disposable live-test environment variables were not supplied.
- Focused backend launch and managed-route suite: 20 passed.
- Focused native launcher, platform bridge, and managed-launch suite: 16 passed.
- Windows release build: succeeded, including the native interactive-user token bridge.
- Side-by-side package installed at `C:\Users\K1\AppData\Local\OpenHUB\OpenHUB-Windows-1.22.0-20260810-200038`.
- Installed package contains one top-level Flutter executable, `OpenHUB.exe`, and no `openhub_windows.exe`.
- Desktop, Start Menu, and Startup shortcuts resolve through the stable installed launcher and use the installed `OpenHUB.exe` icon.
- Embedded manifest extracted from the installed executable declares `requireAdministrator` and `uiAccess=false`.
- Installed package SHA-256 verification completed with zero mismatches.
- Installed identity asset is RGBA with alpha range 0-255; generated ICO frames are 16, 24, 32, 48, and 256 pixels.
- A clean disposable-data smoke against the installed sidecar returned `status=ok`, public version `1.22.0`, and native managed-route protocol `2`; the smoke data path was not the live openhub data directory.
- The native client requires managed-route protocol `2`, so it fails closed instead of attaching to an older OpenHUB sidecar that shares the public release version.
- If an older elevated OpenHUB still owns the loopback port, the installed client now surfaces an explicit full-exit instruction instead of only a generic occupied-port error.
- Separate Desktop and Start Menu shortcuts are installed for opening the HUB itself and for opening Codex through the current Auto Route preference.
- The persistent Auto Route state was enabled in OpenHUB-owned storage at revision 3. Immediate before/after SHA-256 comparison confirmed that Codex `config.toml` and `auth.json` remained unchanged.

## CRITICAL

- Task 6.13 remains incomplete: capture the newly installed Overview shell at the approved viewport and record the final installed visual comparison. The available automation session could not capture the elevated application window, so this is not represented as complete.

## WARNING

- A live managed-route proof requires fully quitting every currently running package-owned Codex process and starting a fresh one through OpenHUB. That action would terminate the active Codex task hosting this verification. The currently active Codex process tree predates the final package and has neither override. The new launcher now fails closed unless the fresh package-owned `codex.exe app-server` command line contains both expected loopback overrides; final traffic/account attribution must be checked after the operator performs that restart.

## Tooling note

The repository does not provide an OpenSpec executable. Direct `openspec` validation was unavailable, and prior project evidence documents that `npx openspec` resolves an unusable `0.0.0` package. Validation therefore used the skill's graceful-degradation path: direct review of proposal, design, tasks, delta specs, implementation, tests, and installed artifacts.

## Assessment

One verification artifact and one user-mediated fresh-process runtime proof remain before archival. The implementation and installed package are ready for that final restart test.
