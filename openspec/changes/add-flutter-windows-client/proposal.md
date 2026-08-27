## Why

The current operator dashboard is a React/Vite single-page application that must be rebuilt and bundled whenever its UI changes. On this Windows workstation, openhub is also launched through an unpinned `uvx --upgrade` command, so a normal launch can replace the installed backend before the operator has reviewed or tested it. The native client must remove both sources of drift without moving, rewriting, or exposing the existing encrypted account store.

## What Changes

- Add a Flutter Windows desktop client with native navigation and controls for Dashboard, Reports, Accounts, APIs, Settings, and Automations.
- Present the native product as `OpenHUB` with the approved dark Signal Slate visual system, a Balanced Routes application mark, adaptive Windows navigation, and accessible state contrast.
- Keep the existing FastAPI service and `~/.openhub` data directory as the single source of truth; the Flutter process consumes only documented dashboard APIs and never reads token or encryption-key material.
- Add a managed local-runtime contract: bind only to loopback, pin the backend artifact, wait for readiness, distinguish an already-running compatible service from an owned child process, and stop only the child process the app owns.
- Add a preflight preservation contract that validates the data directory and creates a verified local backup before a managed backend is allowed to migrate or write the live store.
- Replace ambiguous cached statistics with source-specific freshness metadata, explicit refresh state, and isolated failure handling.
- Add a safe Codex launch integration that never reads, writes, replaces, or isolates Codex configuration, authentication, sessions, history, SQLite state, or Chromium profile. Managed routing is enabled or disabled only in OpenHUB-owned state and applies only to the next Codex process.
- Add a canonical Windows entry point that detects the exact installed Codex AppX process and supports both automatic best-capacity selection and an independent one-launch manual account choice. Either managed path pins one account for the lifetime of the next Codex process and starts the exact installed desktop executable with a process-scoped loopback base-URL override—without exporting, copying, or re-owning OAuth credentials.
- Add local Windows build, package, smoke, data-preservation, and performance gates. This local-only fork has no remote, CI, commit, push, or PR workflow.

## Capabilities

### New Capabilities

- `native-windows-client`: native Flutter UI, local backend lifecycle, data-preserving startup, Codex integration, and Windows packaging contracts.

### Modified Capabilities

- `frontend-architecture`: all six existing operator destinations retain their behavior in the native client, with progressive disclosure and section-local failures.
- `deployment-installation`: local Windows installation uses a pinned sidecar, the existing data-directory resolution rules, and a stable managed-Codex shortcut instead of an upgrading network launcher.

## Impact

- New source: `native_windows/` Flutter application and local packaging/verification scripts.
- Existing backend: API-compatible changes only where native lifecycle, freshness, managed Codex account routing, or integration diagnostics require them.
- Existing data: no schema fork and no token export; `store.db` and `encryption.key` remain canonical and are protected by verified backups.
- Existing web frontend: remains available as a compatibility surface during migration but is not used by the Windows native client.
- Distribution: local Windows artifacts only; repository remotes and release automation are deliberately out of scope.
