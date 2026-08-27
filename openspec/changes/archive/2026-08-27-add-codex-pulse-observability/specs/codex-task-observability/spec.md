## ADDED Requirements

### Requirement: Integrated Codex task pulse

The native OpenHUB client SHALL provide a Pulse destination inside the existing
application. It SHALL NOT require or install a second monitoring application.

#### Scenario: Operator opens Pulse

- **WHEN** an authenticated operator selects Pulse
- **THEN** OpenHUB displays recent Codex tasks in the existing native shell
- **AND** leaving Pulse stops its page-owned refresh and animation loop

### Requirement: Read-only task discovery

Pulse MUST discover recent non-archived Codex tasks from the newest local Codex
state database in read-only mode and MUST NOT mutate the database or rollout
history. It SHALL enrich each task from a bounded tail of its rollout and cache
unchanged parses.

#### Scenario: Codex is writing while Pulse refreshes

- **WHEN** the state database or rollout is being updated concurrently
- **THEN** Pulse performs a short read-only refresh
- **AND** a transient read failure preserves the last valid snapshot with an
  explicit degraded-source message

### Requirement: Semantic task lifecycle

Every visible task SHALL show model, provider, status text, a non-color status
symbol, last activity, session token delta, and context use when available.
Supported states SHALL include active, reasoning, tool activity, retrying,
stalled, failed, cancelled, idle, and unknown.

#### Scenario: Ox request is retrying

- **GIVEN** bridge metrics associate a retrying active request with a task
- **WHEN** Pulse refreshes
- **THEN** that task is labeled Retry with an amber signal and retry count
- **AND** the same state is conveyed through text and icon semantics

#### Scenario: Task completes with an error

- **WHEN** the latest lifecycle completion contains an error
- **THEN** Pulse labels the task Failed and exposes a bounded error summary
- **AND** it does not continue animating the task as active

### Requirement: Session and rolling token accounting

Pulse SHALL show token consumption since the current Pulse service started and
positive token deltas observed in the last minute and last hour. It MUST NOT
report negative usage when a stored counter resets or decreases.

#### Scenario: Tokens increase while Pulse is open

- **WHEN** a task token counter increases between samples
- **THEN** the positive delta contributes to session, one-minute, and one-hour
  totals according to its sample timestamp

### Requirement: Loopback bridge observability

Pulse SHALL query only the configured local Ox bridge health/metrics endpoints.
It SHALL show bridge version, health, active requests, phase, retry attempt, and
bridge token windows when the adapter supplies them. When the adapter exposes
admission telemetry, Pulse SHALL also show queued requests, admitted slots,
in-flight serialized bytes, byte budget, and shared cooldown state. It SHALL
show a degraded state when the bridge is unavailable or older than the metrics
contract.

#### Scenario: OpenAI mode with bridge idle

- **WHEN** the current profile mode is OpenAI and the shared Ox bridge has no
  active inference
- **THEN** Pulse shows OpenAI as the profile mode and bridge idle/healthy as a
  separate fact rather than treating the bridge as the active provider

#### Scenario: Ox work is locally queued

- **GIVEN** admitted Ox work has reached its concurrency or serialized-byte
  budget
- **WHEN** another task reaches the bridge
- **THEN** the bridge keeps the client stream alive while the task waits in a
  cancellation-aware queue
- **AND** Pulse labels the matching task Queued and shows aggregate queue and
  pressure telemetry without exposing prompt content

### Requirement: Quality-preserving Ox request economy

The local Ox adapter MUST bound simultaneous logical inference by both request
count and aggregate serialized request bytes. Retryable overload SHALL reduce
the admission ceiling and establish a shared bounded cooldown; successful
completions SHALL restore capacity gradually. Cancellation MUST remove queued
work and release admitted capacity.

The adapter MAY compact a repeated tool output only when it is byte-for-byte
identical to an earlier large tool output in the same logical request. It MUST
retain the first full result and MUST NOT summarize or remove unique user,
assistant, system, tool, file, compaction, or multi-agent context.

#### Scenario: Concurrent large requests exceed local capacity

- **WHEN** a burst exceeds either the current slot limit or byte budget
- **THEN** excess requests wait in FIFO order instead of starting another
  upstream inference
- **AND** retries for each admitted logical request remain inside that request's
  single admission lease

#### Scenario: Exact large tool output repeats

- **WHEN** a later large tool output exactly matches an earlier output in the
  same request
- **THEN** the first full output remains in the upstream conversation
- **AND** the later copy may become a bounded hash/reference marker with saved
  bytes reported only as aggregate telemetry

### Requirement: Safe provider switching

Pulse SHALL delegate provider changes exclusively to the existing provider
switcher without bypassing its running-Codex confirmation or safety checks.

#### Scenario: Operator selects Ox while Codex is running

- **WHEN** the operator activates Switch to Ox
- **THEN** the existing switcher asks for confirmation before closing Codex
- **AND** Pulse reports success, cancellation, or failure without directly
  editing Codex configuration or task history

### Requirement: Validated task deep link

Selecting a task SHALL open `codex://threads/<uuid>` through a native method that
accepts only a canonical UUID and constructs the scheme internally.

#### Scenario: Invalid task identifier

- **WHEN** a caller supplies a non-UUID task identifier
- **THEN** the deep-link request is rejected before invoking the operating shell
