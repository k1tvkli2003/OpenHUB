## Context

openhub already owns OAuth, encrypted credentials, quota refresh, routing, API-key policy, and SQLite migrations in Python. Reimplementing those domains in Dart would create two authorities and put the existing fifteen-account store at risk. The Flutter application is therefore an operator client and lifecycle supervisor, not a second backend.

The local data directory currently contains a valid SQLite store plus its Fernet key. That pair must stay together and must never be copied into the application source tree, test fixtures committed to source control, logs, or API responses.

## Goals and non-goals

Goals:

- Native Windows rendering and interaction with no WebView and no Vite build in the normal edit/run loop.
- Behavioral parity for the six current dashboard destinations.
- Deterministic local startup against a pinned backend artifact.
- Zero-loss adoption of the current data directory.
- Truthful freshness and partial-failure states.
- Zero-mutation Codex launch integration: Codex-owned configuration and data remain byte-for-byte outside OpenHUB's write scope.
- Deterministic pre-launch selection of the best remaining openhub account, fixed for one Codex process lifetime, without another OAuth flow or a second refresh-token owner.
- Measured startup, refresh, rebuild, and large-list behavior.

Non-goals:

- Reimplementing proxy, OAuth, routing, quota, or database logic in Dart.
- Changing account identities, token encryption, or the canonical data schema merely for the UI rewrite.
- Replacing the ChatGPT sign-in identity displayed by Codex; the selector controls the local upstream route, not OpenAI login identity.
- Publishing, committing, pushing, creating a PR, or reconnecting a Git remote.
- Removing the web frontend before the native parity gate is complete.

## Architecture

```text
Flutter Windows process
  |-- native pages and application state
  |-- loopback API client (127.0.0.1 only)
  |-- backend supervisor
  |-- HUB-owned launch-mode state and capability detection
  |-- managed Codex pre-launch selector and Windows launcher
  `-- owned-child lifecycle
          |
          v
Pinned openhub backend sidecar
  |-- existing FastAPI APIs
  |-- fail-closed managed Codex route pin
  |-- existing migrations and services
  `-- canonical C:/Users/<user>/.openhub
          |-- store.db
          `-- encryption.key
```

The client uses a single typed HTTP boundary. Feature repositories decode JSON into immutable Dart models; widgets never parse maps directly. Sensitive token fields are neither requested nor represented in client models.

## Runtime ownership

1. Resolve and validate the loopback endpoint and data directory.
2. If a ready, compatible backend already owns the configured port, attach without claiming ownership.
3. Otherwise verify that the port is free, verify/create a preservation backup, and start the pinned sidecar with an explicit loopback host, port, and data directory.
4. Poll liveness and readiness with bounded timeouts and surface captured non-secret diagnostics on failure.
5. On app shutdown, request graceful drain/termination only for the exact child process started by this client. Never terminate an attached service by name or port alone.

Compatibility includes both the pinned public backend version and a native managed-route protocol marker. This lets a side-by-side update fail closed instead of attaching to an older OpenHUB-owned sidecar that shares the public release number but lacks a required routing repair.

The packaged client is named `OpenHUB.exe` and locates its sidecar relative to that executable. Development mode may use an explicit local command supplied by the checked-out source, but it must not invoke `uvx --upgrade` or resolve an unpinned latest version. Packaging, launchers, installed-version pointers, shortcut icon locations, and Windows version metadata use the same executable name; the legacy `openhub_windows.exe` filename is not shipped.

The Windows runner embeds `requireAdministrator` with `uiAccess=false`. Consequently, every executable or installed-launcher start crosses the normal Windows UAC consent boundary before the Flutter shell or an owned backend is initialized. Elevation is declared by the executable manifest rather than inferred from a particular shortcut, so copied and side-by-side installations retain the same guarantee.

Because OpenHUB itself is elevated while the packaged Codex desktop must run in the interactive user's normal session, managed launch crosses a narrow native Windows bridge. The bridge validates the exact installed `OpenAI.Codex` `ChatGPT.exe`, reconstructs the interactive shell environment, adds only the two fixed numeric-loopback app-server overrides, and starts Codex with the interactive shell token. Arbitrary executables, hosts, paths, environment keys, account identifiers, and credential values are rejected. OpenHUB then inspects the package-owned `codex.exe app-server` command line and reports success only after both non-secret route overrides are observed.

## Data preservation

Before the first managed write for a backend build/data-store pairing, the supervisor creates a timestamped sibling backup containing the SQLite database, WAL/SHM companions when present, the encryption key, and migration lock metadata. It verifies byte hashes for copied files and runs SQLite integrity checking on the copy. A failed or incomplete backup blocks managed startup. Tests use a disposable copy and never point at the live data directory.

The native client does not introduce a second database. Backend migrations remain the sole schema writer. Backups are additive and never deleted automatically.

## UI and state

The `OpenHUB` shell uses the approved dark Signal Slate system for this local Windows release. Its adaptive left navigation groups Overview, Accounts, and Traffic under Core; groups API access and Automations under Tools; and pins Settings plus runtime health at the rail foot. The approved shell reference uses a compact live brand lockup instead of a detached oversized mark: the transparent Prismatic Gate asset, the live `OpenHUB` name, and the `Local account router` descriptor share one scan group. The selected destination keeps a stable cyan rail, tinted surface, icon, and label treatment; keyboard focus remains equally visible. The shell expands at 1008 logical pixels and above, compacts from 641 through 1007, and uses a labeled minimal navigation presentation at 640 and below. Overview owns the persistent managed-routing status and enable/disable action because it is a frequent global operation. Accounts owns contextual one-launch actions beside each account because the action modifies that selected object. Settings explains integration and safety boundaries without duplicating either primary control. Each page owns loading, empty, ready, refreshing, stale, permission-denied, and failure states. A failing request-log section does not remove healthy dashboard quota/account content.

The approved navigation preview is retained at `work/qa/openhub-approved-navigation.png`. Its production decomposition is: Prismatic Gate as a workspace raster asset; name, descriptor, group labels, destinations, and runtime state as live semantic Flutter widgets; Material Symbols as live functional icons; and selection, hover, press, focus, compact, and minimal states as code-native presentation. No navigation text or live status is flattened into the reference image. The initial visual comparison viewport is 1672 by 941 pixels; adjacent compact and minimal widths remain separate responsive verification targets.

The first vertical slice is runtime status plus Dashboard and Accounts. Subsequent slices reuse the same typed client, refresh coordinator, permission model, and error vocabulary rather than creating page-specific networking stacks.

## Freshness

Every data-bearing surface tracks `lastSuccessfulFetch`, `refreshStartedAt`, and error state separately. Opening the app waits for backend readiness and requests fresh overview/account data. Manual refresh deduplicates concurrent requests and updates only successfully returned sections. Stored usage timestamps remain visible so a successful API call cannot be mistaken for newly fetched upstream quota.

## Codex integration

OpenHUB never edits or swaps Codex-owned state. In particular, it does not write `config.toml`, `auth.json`, Codex SQLite files, session/history directories, or the Chromium profile, and it does not set `CODEX_HOME` or `CODEX_SQLITE_HOME`. Existing recovery backups are retained as inert recovery artifacts but are not part of the managed-launch flow.

The packaged backend also excludes the legacy `codex-sessions retag` implementation and the public CLI no longer exposes that command. Account import remains confined to OpenHUB's own encrypted store; it is not a write into Codex-owned authentication or session files.

Managed routing is a persistent OpenHUB-owned toggle that defaults to disabled. When disabled, `Open Codex` starts the exact installed desktop executable with its normal environment and performs no account preparation. When enabled, the setting affects only a future Codex process; toggling it while Codex is running does not modify or restart that process. The UI states when a restart is required and always offers an immediate disable action.

Manual launch is independent of the automatic-routing toggle. The operator may select any currently eligible local account and choose `Open with selected account`; that one launch validates the named account after refreshing canonical usage, pins it with fallback disabled, and does not alter the persistent automatic-routing preference. Ineligible, missing, stale, paused, or exhausted selections are blocked with the account-specific reason.

For a managed launch, OpenHUB uses the installed desktop build's supported process-scoped app-server base-URL overrides while retaining the built-in `openai` provider and the existing Codex home. ChatGPT-authenticated and API-key Codex sessions use different app-server base URL keys, so the launcher injects both `CODEX_APP_SERVER_CHATGPT_BASE_URL=http://127.0.0.1:<port>/backend-api/codex-managed` and `CODEX_APP_SERVER_OPENAI_BASE_URL=http://127.0.0.1:<port>/backend-api/codex-managed/v1` into the new desktop process. Both paths converge on the same fail-closed prepared account. The loopback URLs contain a fixed non-secret managed path segment; no secret or selected-account identifier appears in the environment or process arguments. Because these overrides are internal desktop capabilities rather than a stable public interface, the launcher detects both in the exact installed package and fails closed to normal launch with a truthful compatibility error if managed mode is requested on an unsupported build.

Before a managed launch, OpenHUB first verifies that no Codex desktop process is already running. Windows AppX detection resolves the installed `OpenAI.Codex` package root and recognizes every package-owned `ChatGPT.exe` or `codex.exe` process, including helpers with no visible window, instead of matching unrelated ChatGPT or generic process names. A visible exact window is focused. A background-only package instance blocks managed preparation with a full-exit explanation because Electron would reuse its old process environment; normal launch may still reactivate it. The backend refreshes usage only where the canonical refresh policy considers the real usage-history sample stale, excludes ineligible or untrustworthy samples, and deterministically ranks the remaining candidates by the minimum of every known finite applicable quota window, capacity-aware remaining credits, freshness, and stable account ID. Missing primary data does not exclude a fresh secondary-only or monthly-only account, while an account with no known finite window remains unknown rather than fully unused. If no trustworthy candidate remains, launch is blocked with per-account reasons. The selected account controls routed request usage and does not rewrite the login identity rendered by Codex; copy uses `prepared` before traffic and `verified` only after observed managed traffic, never `logged in as`.

Each launch attempt begins by clearing superseded one-shot preparation and failure presentation, then publishes exactly one outcome for normal launch, managed launch, blocked selection, or already-running focus. The durable integration state remains separate from attempt feedback so a previous exclusion cannot appear under a later normal-launch heading.

The Prismatic Gate identity asset is a workspace-owned transparent square canvas containing only a broken faceted hexagon and its decisive negative-space route. Cyan/teal facets represent the account pool, the amber facet represents the selected path, and the restrained ultraviolet transition communicates orchestration. It deliberately has no tile, matte, plate, or opaque background. Build tooling derives 16, 24, 32, 48, and 256 pixel Windows ICO frames from that master and the Flutter shell uses the same asset for identity continuity. Alpha-channel and small-size inspection are release gates; ImageGen output is not shipped directly from its cache path.

The selected launch route stores only a local account identifier, score inputs, revision, and timestamp in a private, atomically replaced OpenHUB state file under its own data root. The proxy accepts the dedicated managed URL path only from a numeric loopback peer, removes that path prefix before every upstream HTTP or WebSocket connection, and enforces the prepared account with fallback disabled. OpenHUB launches the exact installed Windows Codex executable only after the persisted route is read back and verified.

No account switch is performed while Codex is running. The pin remains fixed for that process lifetime; the next comparison happens only after Codex has closed and the operator launches or restarts it through the canonical OpenHUB shortcut or the in-app action. Existing continuity therefore cannot be rebound by a background quota update. Flutter receives account metadata and selection evidence only and never calls the credential-export endpoint. Starting the AppX entry directly bypasses preflight, may reuse the last prepared pin, and is explicitly disclosed as an unmanaged launch path.

## Performance budgets

Budgets are measured on a local Windows release build after warm disk cache:

- shell visible within 750 ms of process start;
- ready-or-actionable runtime state within 3 s when the sidecar is already warm;
- navigation response within one frame for cached pages;
- no duplicate fetch caused by widget rebuilds;
- account-list scrolling remains smooth for at least 250 synthetic rows;
- background polling pauses when the app is not visible and uses one shared timer per resource family.
- managed launch readiness loads only authentication, integration status, and launch-route state before preflight; unrelated dashboard fan-out begins after the launch decision and MUST NOT be duplicated.

Measurements and machine/toolchain metadata are stored with the local verification output. A budget miss is reported, not hidden by increasing the threshold.

## Risks and mitigations

- Backend packaging may miss dynamic Python resources: add a packaged-sidecar health and API smoke test from a clean staging directory.
- SQLite migrations may modify live data: verified backup is a hard precondition and migration tests use only a copied store.
- OAuth callbacks may be disrupted by process supervision: retain the backend's existing callback port and test the real flow without exposing credentials.
- OpenAI refresh tokens rotate and cannot safely have two simultaneous owners: keep refresh/access token material exclusively inside the existing openhub account service; managed routing stores IDs only and never reads or copies credentials into Codex `auth.json`.
- The desktop process-scoped override is version-specific: detect the exact capability before enabling managed mode, retain normal launch as the safe path, and never compensate by editing Codex configuration.
- A mid-session account switch could break sticky work: never recompute or mutate the prepared pin while Codex is running; recompute only before the next managed process launch.
- A stale or partial refresh could pick the wrong account: reuse canonical refresh policy, exclude untrustworthy samples, expose score inputs and sample time, and block launch when no trustworthy candidate remains.
- A native parity gap may strand a power feature: keep the web compatibility UI until the six-destination inventory is closed.
- Windows C++ tooling may be absent: source analysis and Dart tests can proceed, but release completion requires the Flutter-supported Visual Studio desktop workload and a real release launch.
