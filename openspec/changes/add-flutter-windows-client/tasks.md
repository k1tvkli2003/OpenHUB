## 1. Preservation and baseline

- [x] 1.1 Disconnect every Git remote and record the local-only/no-commit constraint.
- [x] 1.2 Confirm the backend is stopped and create a timestamped verified backup of the live database and encryption key.
- [x] 1.3 Record current database integrity, account count, usage-history count, launcher behavior, Codex configuration state, and Windows toolchain blockers without exposing credentials.
- [x] 1.4 Build disposable migration/runtime fixtures from the verified backup; tests must reject the live data path.

## 2. Native foundation

- [x] 2.1 Scaffold a Windows-only Flutter application under `native_windows/`.
- [x] 2.2 Implement the native shell, core/advanced navigation, theme, accessibility semantics, and window lifecycle.
- [x] 2.2a Apply the OpenHUB identity, approved Prismatic Gate icon, dark Signal Slate tokens, adaptive navigation breakpoints, and accessible state contrast.
- [x] 2.3 Implement typed API transport, cookie/session handling, permission state, cancellation, error decoding, and section-local refresh coordination.
- [x] 2.4 Implement loopback endpoint validation and backend readiness/version checks.

## 3. Backend lifecycle and preservation

- [x] 3.1 Implement attached-versus-owned backend discovery and exact child-process ownership.
- [x] 3.2 Implement verified preflight backup and block managed startup on preservation failure.
- [x] 3.3 Package a pinned backend sidecar and resolve it relative to the native executable.
- [x] 3.4 Add graceful drain/stop, crash diagnostics, restart, and occupied-port handling.

## 4. Feature parity

- [x] 4.1 Migrate Dashboard overview, projections, request logs, manual refresh, and partial-failure behavior.
- [x] 4.2 Migrate Accounts listing/detail, import/OAuth, pause/reactivate, alias/policy edits, probe/reset-credit flows, export, and guarded deletion.
- [x] 4.2a Add launch-candidate evidence, the fixed process-lifetime route badge, exact exclusion/failure reasons, and a managed `Open Codex` action that requires the current Codex process to be closed, without exposing credential material to Dart.
- [x] 4.3 Migrate Reports with local-timezone range semantics.
- [x] 4.4 Migrate API keys, model access, limits, trends, and one-time secret presentation.
- [x] 4.5 Migrate Settings including appearance/auth, routing, upstream proxies, model sources, firewall, quota planner, sticky sessions, retention, and progressive disclosure.
- [x] 4.6 Migrate Automations listing, filters, editor, run history/details, run-now, and deletion.

## 5. Correctness fixes

- [x] 5.1 Surface source-specific timestamps and distinguish API-cache success from fresh upstream quota.
- [x] 5.2 Deduplicate startup/manual/background refresh and preserve healthy sections when one endpoint fails.
- [x] 5.3 Remove Codex provider/configuration mutation from every launch and Settings path; retain old backups only as inert recovery artifacts.
- [x] 5.4 Replace the upgrading launcher with a pinned native launch path while retaining an explicit compatibility fallback.
- [x] 5.5 Harden local backup/key permissions without changing token encryption or exposing secret material.
- [x] 5.6 Add stale-aware deterministic pre-launch scoring, loopback-only managed marker, private atomic process-lifetime route state, central fail-closed enforcement, upstream header stripping, audit logging, prepare-launch/status APIs, and safe installed-Codex discovery/launch.
- [x] 5.7 Add an idempotent managed-launch startup intent, exact current AppX process detection, HUB-owned enable/disable state, process-scoped desktop override, direct installed-executable launch, and stable Windows shortcut wiring.
- [x] 5.8 Add an independent manual account picker and one-launch named-account preparation that does not change the automatic-routing preference.
- [x] 5.9 Rank launch candidates from every known finite quota window, including secondary-only and monthly-only samples, and expose a dedicated usage-sample timestamp instead of reusing credential refresh time.
- [x] 5.10 Scope launch preparation, failure, and already-running feedback to the current attempt; focus an existing Codex window without preparing, restarting, or mutating its route.
- [x] 5.11 Move the managed-routing enable/disable control to Overview and place one-launch manual account actions beside their Accounts objects with complete in-context explanations.
- [x] 5.12 Replace the OpenHUB launcher and in-app identity mark with the approved transparent Prismatic Gate asset and generate verified multi-resolution Windows icon frames.
- [x] 5.13 Require administrator elevation in the Windows executable manifest so every direct or shortcut launch passes through the standard UAC consent boundary.
- [x] 5.14 Ship the Windows client as `OpenHUB.exe` and remove the legacy executable filename from package, launcher, installer, shortcut-icon, and version-resource contracts.
- [x] 5.15 Rebuild the in-app identity and navigation from the approved OpenHUB preview: a crisp compact brand lockup, Core/Tools grouping, Settings/runtime utilities at the rail foot, explicit selected/focus states, and labeled minimal navigation.
- [x] 5.16 Repair managed account routing for ChatGPT-authenticated Codex by setting both process-scoped ChatGPT and OpenAI base URLs, blocking managed launch while any package-owned Codex process remains alive, and replacing login-switch claims with truthful routed-usage language.
- [x] 5.17 Apply one global remaining-usage order to every account list and picker, default to highest remaining first, expose both high-to-low and low-to-high controls, keep unknown usage last, and use stable tie-breaking.

## 6. Local verification and packaging

- [x] 6.1 Add unit/widget tests for typed decoding, auth/session, state transitions, navigation, destructive confirmations, and refresh isolation.
- [x] 6.2 Add backend contract tests for every consumed endpoint and fields relied on by Dart models.
- [x] 6.2a Prove with synthetic accounts that pre-launch ranking is deterministic, stale/unknown/ineligible candidates cannot win, the verified pin cannot fall back or change mid-process, launch waits for preparation, already-running Codex is not re-pinned, and the marker never reaches upstream.
- [x] 6.3 Run copied-store migration/startup tests and prove live-store hashes are unchanged by test runs.
- [x] 6.4 Run analyze, tests, release build, clean-staging packaged-sidecar smoke, and real Windows launch locally.
- [x] 6.5 Measure startup, warm readiness, navigation, refresh duplication, and 250-row list behavior against the declared budgets.
- [x] 6.6 Complete a six-destination parity ledger and retain the web compatibility UI until every required row is verified.
- [x] 6.7 Prove automatic managed-launch ordering, already-running no-mutation behavior, exact process detection, launch-critical request isolation, stable shortcut forwarding, and live installed setup without restarting the active Codex session.
- [x] 6.8 Prove hashes of Codex `config.toml` and other sampled Codex-owned state do not change across enable, disable, automatic preparation, manual preparation, normal launch, or managed-launch dry-run tests.
- [x] 6.9 Add regressions for secondary-only eligibility, true usage-sample freshness, stale-attempt feedback clearing, existing-window focus, Overview routing controls, and per-account launch actions.
- [x] 6.10 Rebuild, install side-by-side, inspect Overview and Accounts at representative Windows sizes, verify 16/32/256 icon frames, and re-prove Codex-owned state hashes without closing the active Codex process.
- [x] 6.11 Extract the packaged executable manifest and verify that OpenHUB declares `requireAdministrator` with `uiAccess=false`.
- [x] 6.12 Rebuild and install a side-by-side package whose only Flutter executable is `OpenHUB.exe`; verify launchers, shortcuts, version metadata, elevation manifest, and absence of `openhub_windows.exe`.
- [ ] 6.13 Capture the installed Overview shell at the approved viewport, compare it side-by-side with the approved navigation preview, and record responsive, focus, clipping, and icon-fidelity results.
- [x] 6.14 Add regressions for background-only Codex processes, ChatGPT/OpenAI dual process overrides, normal background reactivation, managed fail-closed behavior, and routed-account verification language; prove Codex-owned file hashes remain unchanged.
- [x] 6.15 Add unit, widget, and 250-row performance regressions for global remaining-usage ordering in both directions, stable ties, unknown usage placement, and live control updates.
