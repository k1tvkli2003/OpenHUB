# native-windows-client Delta

## ADDED Requirements

### Requirement: Windows operator UI is native Flutter

The Windows operator application MUST render its shell, navigation, data, controls, dialogs, and status surfaces with Flutter widgets and MUST NOT embed the React dashboard in a WebView. Normal native UI edits MUST NOT require a Vite build.

#### Scenario: Native client starts without web assets

- **GIVEN** the packaged Flutter executable and pinned backend sidecar are present
- **AND** no built React dashboard assets are present in the native package
- **WHEN** the operator starts the Windows application
- **THEN** the native shell and runtime status render successfully
- **AND** dashboard API operations remain available

### Requirement: Native product identity and anatomy are coherent

The Windows application MUST use the user-facing name `OpenHUB`, the approved Prismatic Gate application mark, and the dark Signal Slate design system across window metadata, navigation, about/status surfaces, and packaging metadata. The expanded identity surface MUST present a compact live brand lockup rather than a detached oversized mark. Expanded navigation MUST group Overview, Accounts, and Traffic under Core, group API access and Automations under Tools, and place Settings plus runtime status in the utility region. Navigation MUST adapt without hiding any destination at the declared expanded, compact, and minimal breakpoints, minimal navigation MUST keep labels visible, state contrast MUST remain accessible, and keyboard focus MUST remain visible.

#### Scenario: Shell crosses navigation breakpoints

- **WHEN** the operator resizes the window across 1008 and 640 logical pixels
- **THEN** the navigation changes between expanded, compact, and minimal presentations without overflow
- **AND** Overview, Accounts, Traffic, API access, Automations, and Settings remain reachable
- **AND** the current destination and keyboard focus remain unambiguous
- **AND** the Prismatic Gate remains crisp, optically aligned, and attached to the live product name at every presentation size

### Requirement: Existing backend and data directory remain authoritative

The native client MUST use the existing backend APIs and resolved openhub data directory as the sole authority for accounts, encrypted tokens, usage, routing, settings, API keys, and automations. It MUST NOT read, decrypt, duplicate, export, or log stored access tokens, refresh tokens, or the encryption key.

#### Scenario: Existing store opens without token migration

- **GIVEN** a valid existing `store.db` and matching `encryption.key`
- **WHEN** the native client adopts that data directory
- **THEN** account identities and history are served by the existing backend
- **AND** the client performs no token export or Dart-side credential migration

### Requirement: Managed startup is preservation-gated

Before starting an owned backend that may migrate or write an existing store, the client MUST create a timestamped local backup of the database, non-empty SQLite companion files, encryption key, and migration metadata. The client MUST verify copied-file hashes and SQLite integrity. A failed backup or verification MUST block the owned backend start with an actionable error.

#### Scenario: Backup verification failure blocks live startup

- **GIVEN** an existing data directory
- **AND** one required file cannot be copied or its verification fails
- **WHEN** the client attempts a managed start
- **THEN** no owned backend process is started
- **AND** the live data directory is not modified by the client
- **AND** the operator sees the failed preservation check and affected path

### Requirement: Tests never run against the live data directory

Automated native, backend-contract, migration, and packaging tests MUST resolve a disposable data directory outside the live `~/.openhub` path. Test startup MUST fail closed if the resolved test directory is the live path or contains the app-recorded live-store identity.

#### Scenario: Test configuration points at live data

- **WHEN** a local verification command resolves the live openhub data directory as its test target
- **THEN** it exits before starting the backend or writing any file
- **AND** it reports that a disposable copied fixture is required

### Requirement: Backend process ownership is exact

The client MUST distinguish an already-running compatible backend from the exact child process it starts. It MAY attach to a compatible loopback service, but on shutdown or restart it MUST terminate only the child process it owns and MUST NOT kill a process solely because its name or listening port matches.

#### Scenario: Client attaches to an existing backend

- **GIVEN** a compatible ready backend already listens on the configured loopback endpoint
- **WHEN** the native client starts and later exits
- **THEN** it attaches without starting a duplicate process
- **AND** it leaves the existing backend running on exit

### Requirement: Native management traffic stays on loopback

The managed backend MUST bind to `127.0.0.1` and the native API client MUST reject non-loopback HTTP endpoints unless a future explicit remote-management capability defines authentication and transport requirements.

#### Scenario: Non-loopback endpoint is configured

- **WHEN** native startup resolves a hostname or address that is not loopback
- **THEN** the management connection is rejected before credentials, cookies, or mutations are sent

### Requirement: Data freshness is explicit and section-local

Every native data section MUST distinguish loading, refreshing, ready, stale, and failed states and expose the time of its last successful fetch. Usage surfaces MUST also expose the backend-provided sample time so cached history is not represented as a newly fetched upstream quota. A failure in one dashboard section MUST NOT remove successfully loaded independent sections.

#### Scenario: Request logs fail while overview succeeds

- **WHEN** overview data succeeds and request-log loading fails
- **THEN** overview statistics and account controls remain visible
- **AND** request logs show a local error and retry action
- **AND** freshness labels do not advance for the failed section

### Requirement: Codex-owned configuration and data are never mutated

OpenHUB MUST NOT read, write, replace, relocate, or isolate Codex `config.toml`, `auth.json`, SQLite state, sessions, history, skills, logs, or Chromium profile. It MUST NOT set `CODEX_HOME` or `CODEX_SQLITE_HOME` for launch. Managed mode and prepared-route state MUST live only under the OpenHUB data root.

#### Scenario: Operator enables or disables managed routing

- **WHEN** the operator changes the managed-routing toggle
- **THEN** only OpenHUB-owned state changes
- **AND** Codex-owned configuration and data hashes remain unchanged
- **AND** an already-running Codex process is not restarted or modified

#### Scenario: Managed routing is disabled

- **GIVEN** managed routing is disabled
- **WHEN** the operator selects `Open Codex`
- **THEN** Codex starts with its normal environment
- **AND** OpenHUB performs no account preparation or Codex-owned state mutation

### Requirement: Managed Codex launch selects the best trustworthy remaining quota

Before opening Codex, the native client MUST request a pre-launch preparation that refreshes stale usage through the canonical backend policy and deterministically selects the eligible account with the greatest effective remaining quota. Effective remaining quota MUST be the minimum of every known finite applicable usage window; an absent primary window MUST NOT invalidate a trustworthy secondary-only or monthly-only sample. An account with no known finite usage window, or with only stale/invalid samples, MUST remain ineligible. Usage freshness MUST derive from usage-history sample time and MUST NOT reuse OAuth or credential-refresh timestamps. The operation MUST store and expose only local account metadata and selection evidence and MUST NOT export tokens, copy credentials into Codex `auth.json`, initiate OAuth merely to launch, or create a second refresh-token owner. A managed launch MUST set process-scoped `CODEX_APP_SERVER_CHATGPT_BASE_URL` to the dedicated managed ChatGPT route and `CODEX_APP_SERVER_OPENAI_BASE_URL` to the dedicated managed OpenAI-compatible route so both ChatGPT-login and API-key request modes reach the same fail-closed account pin without editing `config.toml`.

#### Scenario: Codex is closed and trustworthy candidates exist

- **GIVEN** managed routing is enabled and the installed desktop supports the process-scoped override
- **AND** no Codex desktop process is running
- **AND** at least one eligible account has trustworthy quota data
- **WHEN** the operator selects `Open Codex` or invokes the dedicated managed-Codex entry point
- **THEN** stale candidate data is refreshed according to the canonical refresh policy
- **AND** the deterministic top candidate is atomically pinned and read-back verified
- **AND** Codex is launched only after preparation succeeds
- **AND** both supported process-scoped app-server base URL overrides point at numeric loopback managed routes
- **AND** Flutter receives no access token, refresh token, ID token, encryption key, or exported auth document

#### Scenario: No trustworthy candidate remains

- **WHEN** every account is ineligible, exhausted, unknown, or stale after refresh attempts
- **THEN** the backend returns the per-account exclusion reasons
- **AND** Codex is not launched

#### Scenario: Trustworthy secondary-only quota exists

- **GIVEN** an eligible account has no primary window
- **AND** it has a fresh finite secondary usage sample with remaining capacity
- **WHEN** OpenHUB ranks launch candidates
- **THEN** the account remains eligible
- **AND** its effective capacity and sample timestamp derive from the known usage window
- **AND** missing primary data is represented as unknown rather than zero or fully available

### Requirement: Manual account launch is independent of automatic routing

OpenHUB MUST let the operator select a specific eligible local account as the exclusive routed-usage account for one new Codex process even when automatic routing is disabled. Manual launch MUST validate the selected account through the same fresh, trustworthy eligibility policy, pin it with fallback disabled, and MUST NOT change the persistent automatic-routing preference. The product MUST distinguish this request-routing account from the login identity rendered by Codex itself; it MUST NOT claim that the visible Codex login changed when Codex-owned authentication state was intentionally left untouched.

#### Scenario: Operator opens Codex with a selected account

- **GIVEN** Codex is closed and the selected local account remains eligible after refresh
- **WHEN** the operator selects `Open with selected account`
- **THEN** that exact account is atomically pinned and read-back verified
- **AND** the automatic-routing toggle is unchanged
- **AND** the account stays fixed until that Codex process closes
- **AND** the UI describes the account as the prepared or verified usage route rather than a changed Codex login

#### Scenario: Selected account is unavailable

- **WHEN** the selected account is missing, paused, exhausted, stale, or otherwise ineligible after refresh
- **THEN** launch is blocked with the account-specific reason
- **AND** no fallback account is selected

### Requirement: Prepared account remains fixed for one Codex process

OpenHUB MUST NOT change the prepared account while any process owned by the installed `OpenAI.Codex` package remains running, including background-only `ChatGPT.exe` or bundled `codex.exe` processes with no visible window. It MUST recompute the best account only before a subsequent managed launch after every process from the previous Codex instance has closed. The prepared route MUST disable fallback to another account. Normal unmanaged launch MAY reactivate a background instance, but managed launch MUST fail closed before preparation when a background instance would prevent the process-scoped overrides from taking effect.

#### Scenario: Usage rankings change during an active Codex process

- **GIVEN** Codex was launched with account A
- **AND** account B later reports more remaining quota
- **WHEN** background refresh completes while Codex is still running
- **THEN** the process continues to route only through account A
- **AND** account B is considered only before the next managed launch

#### Scenario: Codex is already running

- **WHEN** the operator invokes the launch action
- **THEN** OpenHUB brings the exact existing Codex window to the foreground when Windows permits it
- **AND** reports that the current account route remains unchanged until Codex fully closes
- **AND** it neither changes Codex configuration or data, rewrites the prepared route, nor starts a duplicate process

#### Scenario: Codex remains alive only in the background

- **GIVEN** no Codex window is visible but at least one executable under the installed `OpenAI.Codex` package root is still running
- **WHEN** the operator requests an automatic or manual managed launch
- **THEN** OpenHUB blocks before preparing or claiming a new account route
- **AND** explains that Codex must be fully quit so the new process can inherit both managed base URL overrides
- **AND** normal unmanaged launch remains able to reactivate the existing instance

### Requirement: Routing controls follow their object and frequency

The persistent managed-routing enable/disable control MUST be visible on Overview beside the current route state. A one-launch manual account action MUST be available beside each eligible account in Accounts. Settings MAY explain the integration but MUST NOT duplicate the primary controls or require a disconnected account picker. Each surface MUST explain whether an action affects the current process, the next process, or one selected launch.

#### Scenario: Operator manages routing from the owning surfaces

- **WHEN** the operator opens Overview
- **THEN** the current managed-routing state and enable/disable action are visible together
- **WHEN** the operator inspects an account in Accounts
- **THEN** a contextual `Open Codex with this account` action is available for that account
- **AND** no separate manual-account dropdown is required in Settings

### Requirement: Launch feedback belongs only to the current attempt

Every launch attempt MUST clear superseded preparation, exclusion, and error presentation before evaluating the new request. Normal launch, blocked managed launch, successful managed launch, and already-running focus MUST each publish one truthful outcome without leaking a prior attempt into the current mode.

#### Scenario: A blocked attempt is followed by an already-running action

- **GIVEN** a previous managed attempt was blocked by account eligibility
- **AND** Codex is now already running
- **WHEN** the operator invokes `Open Codex`
- **THEN** the UI shows only the already-running/focus result for the new attempt
- **AND** the prior exclusion message is no longer presented as the current result

### Requirement: OpenHUB identity is legible at Windows icon sizes

The approved Prismatic Gate concept MUST be stored inside the workspace as an isolated symbol on a genuinely transparent canvas, used by the in-app identity surface, and exported into the Windows executable as a multi-resolution icon containing at least 16, 24, 32, 48, and 256 pixel frames. The icon MUST NOT add a square tile, white matte, or opaque background around the symbol, and the small-size silhouette MUST remain recognizable without text.

#### Scenario: Packaged icon is inspected

- **WHEN** the release executable icon is decoded at 16, 32, and 256 pixels
- **THEN** the broken hexagonal gate and decisive negative-space path remain distinguishable
- **AND** pixels outside the standalone symbol remain transparent without a white halo
- **AND** no generated identity asset is loaded from an external cache at runtime

### Requirement: Managed Codex entry point is automatic and canonical

The installed OpenHUB shortcut MAY pass explicit launch intent to OpenHUB. Once the loopback backend and local session are ready, OpenHUB MUST read its own enable/disable state. Disabled mode launches Codex normally. Enabled mode completes capability detection, stale-aware preparation, route read-back, and process-scoped managed launch without another click. Launch-critical startup MUST NOT wait for unrelated dashboard requests. The installed-process detector MUST resolve the exact `OpenAI.Codex` AppX package root and recognize its window-owning executable even when that executable is named `ChatGPT.exe`.

#### Scenario: Managed shortcut is invoked while Codex is closed

- **WHEN** the operator opens the installed managed-Codex shortcut
- **THEN** OpenHUB completes the launch-critical pipeline before starting Codex
- **AND** unrelated dashboard loading does not delay or duplicate that pipeline

#### Scenario: Direct AppX entry is invoked

- **WHEN** the operator starts the Codex AppX entry without the OpenHUB shortcut
- **THEN** no claim is made that pre-launch account selection occurred
- **AND** the path is documented as unmanaged because a local helper cannot safely intercept it before process start

### Requirement: Managed route trust fails closed

The backend MUST honor the dedicated managed URL path only for a numeric loopback socket peer and MUST remove the path prefix before every upstream HTTP or WebSocket request. A missing, invalid, unavailable, or unprepared launch pin MUST fail without selecting another account.

#### Scenario: Marker arrives from a non-loopback peer

- **WHEN** a request presents the managed URL path from a non-loopback socket peer
- **THEN** the marker is ignored or rejected before account selection
- **AND** the marker is never forwarded upstream

### Requirement: Windows release is self-contained and pinned

The local Windows package MUST include the Flutter release executable as `OpenHUB.exe` and an exact backend sidecar build. The package MUST NOT ship `openhub_windows.exe`, and every package launcher, installer validation, shortcut icon location, and Windows version-resource filename MUST resolve to `OpenHUB.exe`. Launching the package MUST NOT execute `uvx --upgrade`, query a Git remote, or resolve a latest backend version. A clean-staging smoke test MUST prove the packaged app can start the sidecar and reach readiness.

#### Scenario: Packaged app launches without source checkout

- **GIVEN** the release directory has been copied to a clean local staging path
- **AND** no source checkout is on `PATH`
- **WHEN** the application starts
- **THEN** it resolves the bundled sidecar relative to its executable
- **AND** reports a compatible ready backend without downloading or upgrading code

#### Scenario: Package executable identity is inspected

- **WHEN** the release package and installed shortcuts are inspected
- **THEN** the client executable is named `OpenHUB.exe`
- **AND** no shipped launcher, installer contract, shortcut icon, or version resource refers to `openhub_windows.exe`

### Requirement: OpenHUB always requests administrator elevation

The packaged Windows executable MUST declare `requireAdministrator` with `uiAccess=false` in its embedded execution manifest. Every direct executable launch and every shortcut or stable launcher that resolves to that executable MUST therefore pass through the standard Windows UAC consent boundary before OpenHUB initializes its UI or owned backend.

#### Scenario: Operator starts OpenHUB

- **WHEN** the operator starts OpenHUB directly or through an installed OpenHUB launcher
- **THEN** Windows requests administrator consent before the application starts
- **AND** the running OpenHUB process has an elevated token
- **AND** OpenHUB does not bypass UAC or request `uiAccess`

### Requirement: Account presentation follows one remaining-usage order

Every rendered account collection and account picker MUST use one shared remaining-usage order. The operator MUST be able to switch globally between highest remaining usage first and lowest remaining usage first. The default MUST be highest remaining usage first. Accounts without a usable remaining-usage sample MUST stay after accounts with numeric samples in both directions, and equal samples MUST use a deterministic name and account-id tie-break.

#### Scenario: Operator reverses account order

- **GIVEN** account A has more remaining usage than account B
- **WHEN** the operator selects `Usage left · high → low`
- **THEN** account A appears before account B in Overview, Accounts, filters, launch selectors, and administrative account pickers
- **WHEN** the operator selects `Usage left · low → high`
- **THEN** account B appears before account A on those same surfaces
- **AND** accounts with unknown usage remain after both accounts
