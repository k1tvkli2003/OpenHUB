## ADDED Requirements

### Requirement: Unified non-secret profile registry

OpenHUB MUST manage versioned Codex profiles inside the application and MUST
ship built-in OpenAI Pool and Ox profiles. A profile MAY contain provider,
model, catalog, endpoint, and launch policy, but MUST NOT contain account access
tokens, refresh tokens, cookies, copied authentication files, or personal
absolute paths.

#### Scenario: Fresh standalone installation

- **WHEN** OpenHUB starts without a profile registry
- **THEN** it creates valid OpenAI Pool and Ox definitions from installation-
  relative assets and local loopback endpoints
- **AND** no profile contains a credential or the packager's user path

#### Scenario: Legacy profile import

- **WHEN** an operator imports an existing Codex profile file
- **THEN** OpenHUB imports only whitelisted non-secret provider/model/catalog
  settings and reports skipped sensitive or unsupported keys

### Requirement: Automatic canonical Codex discovery

On first run OpenHUB MUST discover the installed official Codex Desktop, Codex
CLI, and canonical Codex home without requiring a machine-specific path. Every
profile MUST run as a process-scoped overlay on that same home and MUST NOT set
or persist a profile-specific `CODEX_HOME` or copy state, sessions, skills,
memories, plugins, or project files.

#### Scenario: First launch on another Windows system

- **WHEN** OpenHUB starts on a supported system with official Codex installed
- **THEN** it discovers Desktop and CLI installation metadata, starts a
  loopback app-server, and adopts its initialized `codexHome` as the canonical
  root before enabling managed profile controls

#### Scenario: Runtime reports a different Codex home

- **WHEN** a target app-server initializes with a `codexHome` different from
  the canonical discovered root
- **THEN** OpenHUB rejects the switch and preserves the prior runtime instead
  of creating, copying, or silently synchronizing a second history root

### Requirement: Transactional live profile switching

Before switching profiles, OpenHUB MUST discover active root-task trees. If any
exist, it MUST require explicit confirmation that identifies the root count.
After confirmation it MUST pause/interrupt live work, fully close Codex, replace
the managed app-server profile, relaunch Codex, and verify adoption. A failed
switch MUST attempt rollback to the prior verified profile and MUST NOT report
success from process creation alone.

#### Scenario: Switch while two subagents are live

- **GIVEN** one active root task has two active descendants
- **WHEN** the operator requests another profile
- **THEN** the confirmation reports one live root task rather than three tasks
- **AND** no process is stopped before confirmation

#### Scenario: Target profile fails readiness

- **WHEN** the target app-server or bridge fails its readiness/adoption check
- **THEN** OpenHUB restores the prior profile when possible
- **AND** reports target and rollback outcomes separately

### Requirement: Loopback managed app-server

On Windows, managed profiles SHALL use a Codex app-server bound only to numeric
loopback and SHALL launch the official Codex desktop against its verified
WebSocket endpoint. Supervisor state MUST be atomic, bounded, and rejected when
its PID, executable, endpoint, CLI version, or health evidence is stale.

#### Scenario: Another local process occupies the recorded port

- **WHEN** supervisor discovery finds a healthy WebSocket endpoint but the recorded
  PID or executable identity does not match the owned app-server
- **THEN** OpenHUB rejects the state and does not send task-control requests

### Requirement: Context-efficient profile transition

OpenHUB MUST resume the same persisted Codex thread history across profiles and
MUST NOT copy rollout histories or project files. Before switching to a smaller
context window, it SHALL compare known context use with the target limit and
SHALL use native app-server compaction when the safe threshold is exceeded.

#### Scenario: Target model has a smaller context window

- **GIVEN** a root task's current context exceeds the target profile's safe
  threshold
- **WHEN** the confirmed switch runs
- **THEN** OpenHUB requests `thread/compact/start` and waits for terminal
  evidence before shutdown
- **AND** does not duplicate the task's files or rollout
