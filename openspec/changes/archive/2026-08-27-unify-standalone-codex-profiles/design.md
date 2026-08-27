## Context

Profiles, accounts, providers, and tasks are separate concepts. A profile is a
non-secret Codex launch policy. An account is an authenticated identity owned by
OpenHUB's existing store. A provider is an inference route. A task is a
`sessionId` tree whose root may own multiple subagent threads.

The installed Windows Codex cannot use the Unix daemon lifecycle, but it exposes
`CODEX_APP_SERVER_WS_URL` and the CLI can listen on loopback WebSocket. The
current app-server schema exposes authoritative task hierarchy, status, goals,
interrupt, resume, and compaction primitives.

## Decisions

### Portable non-secret profile registry

Persist versioned profile definitions under OpenHUB's application data root.
Store stable ids, labels, provider kind, model defaults, catalog policy, and
loopback endpoints only. Never store account tokens, browser cookies, or copied
`auth.json` content. Import legacy profile files by parsing only whitelisted
non-secret keys and resolve all shipped assets relative to the installation.

Every profile is a process-scoped configuration overlay on one canonical Codex
home. OpenHUB never creates profile-specific history/state/skills roots and
never copies rollouts between profiles. First-run discovery locates the
installed Codex Desktop and CLI, resolves the canonical home, initializes a
loopback app-server, and verifies that its reported `codexHome` matches before
profile controls become available.

### One supervised app-server per active profile

OpenHUB starts `codex app-server --listen ws://127.0.0.1:<port>` with profile
configuration overrides and verifies port ownership plus the initialized
JSON-RPC handshake. The desktop is launched with
`CODEX_APP_SERVER_WS_URL` and the process is verified to have adopted that URL.
Supervisor state records PID, endpoint, profile id, and CLI version atomically so
the next OpenHUB process can reattach or reject stale state.

The listener binds numeric loopback only. WebSocket mode is currently marked
experimental by OpenAI; this release treats that as a documented beta boundary
and fails closed on missing capability or health.

### Transactional profile switch

Preflight lists active app-server threads and groups them by `sessionId`. With no
live roots, switch immediately. With live roots, return a confirmation guard.
After confirmation: pause/interrupt live roots, optionally compact roots that
would exceed the target window, close Codex, stop the prior supervisor, start
and verify the target, relaunch Codex, and verify adoption. On failure, restart
the prior profile and report both primary and rollback outcomes.

### Task-level lifecycle semantics

Pause sets an existing root goal to `paused` without replacing its objective or
usage, then interrupts every in-progress turn in the root and descendants.
Tasks without a goal receive a local checkpoint and their in-progress turns are
interrupted. Resume reconnects the exact persisted root thread, restores an
existing goal to `active`, and continues from the interrupted history without
copying history or files. If no persisted goal exists, resume starts one bounded
continuation turn and labels this distinction in the UI.

### Root task and token accounting

Use app-server `thread.sessionId` as the authoritative root identity and
`parentThreadId` for disclosure hierarchy. Sum each unique thread's cumulative
token counter once into its root. Rolling deltas are keyed by child thread id,
then aggregated by root, so child work is visible without becoming a separate
top-level task or being double counted. The bounded rollout parser is a fallback
only when app-server is unavailable.

### OpenAI account pool and continuity

The OpenAI Pool profile uses OpenHUB's managed loopback ChatGPT/OpenAI routes
and live `/codex/models` catalog. An automatic launch selection is a soft first
preference: upstream rate-limit/auth/capacity failures exclude the failed
account and retry through the canonical selector. A manual selection and a file
or previous-response continuity owner remain hard pinned unless existing replay
proof permits migration. No credential crosses the local profile boundary.

### Context-efficient provider changes

Never serialize or resend project files merely to switch profiles. Resume the
same persisted thread in place. Compare observed context use with the target
model window; when unsafe, run native `thread/compact/start` before shutdown and
wait for terminal evidence. Codex's own one-time model-switch instruction and
compaction history remain authoritative.

### Dry-run-first cleaning

Cleaning is product-native, never a generic recursive delete. OpenHUB first
inventories task groups and a strict allowlist of OpenHUB-owned temporary,
cache, stale-log, and release-staging roots. The preview shows exact root task
groups, descendant count, age, category, bytes, exclusions, recovery method,
expiry, and a canonical batch SHA-256. A changed inventory invalidates the
batch and requires a new preview.

Old conversations default to app-server archive, keeping the same task id and
history recoverable. A root and its descendants are one indivisible selection;
a subagent cannot be cleaned as an independent top-level task. File cleanup is
limited to known generated artifacts, rejects active/open files, credentials,
databases, rollouts, project workspaces, reparse points, and paths outside the
resolved allowlist. Material removal uses the Windows Recycle Bin or a bounded
OpenHUB quarantine with a local journal. Permanent deletion, if ever exposed,
is a separate operation with a fresh exact-batch confirmation and is not part
of the default v0.1.0 flow.

### Public release

The first public release is `v0.1.0` for Windows x64. CI on `main` and manual
dispatch runs strict specs, Python and Flutter tests, source/package secret and
personal-path scans, deterministic packaging, checksums, and SBOM generation.
Release assets include a portable ZIP and installer script. Artifacts are
explicitly unsigned until a real signing identity is configured.

## Failure modes

- Existing Codex ignores the managed WS URL: abort and preserve the prior
  profile rather than reporting success.
- Partial interrupt failure: do not kill Codex until the user reconfirms the
  remaining live roots, and expose exact failed thread ids without titles.
- App-server or bridge crash: keep last valid telemetry, mark the profile
  degraded, and offer a bounded restart.
- Rate-limited file owner: fail closed with a continuity explanation; never send
  a file-backed continuation through a different account speculatively.
- Public scan detects a secret or personal path: block release creation.
- Discovery reports a different Codex home than the canonical root: disable
  managed profile controls and require reconciliation instead of splitting data.
- Cleaning inventory changes after preview: invalidate the plan and perform no
  mutation; never silently shrink or regenerate an approved batch.

## Concrete example

An operator switches from OpenAI Pool to Ox while one root task has two live
subagents. OpenHUB reports one live task with two children, asks confirmation,
pauses the root goal, interrupts three in-progress turns, compacts only if Ox's
window requires it, closes Codex, starts the Ox app-server/bridge from packaged
relative paths, relaunches Codex, and verifies the adopted profile. Pulse still
shows one root task and its aggregate tokens after resume.
