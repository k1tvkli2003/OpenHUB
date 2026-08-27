## ADDED Requirements

### Requirement: One normalized task surface covers Codex and Hermes

OpenHUB SHALL expose tasks from Codex and Hermes through one normalized schema
that preserves runtime identity, root/parent lineage, lifecycle, provider,
model, last activity, usage counters, and supported actions.

#### Scenario: Same local id from two runtimes

- **WHEN** Codex and Hermes report an equal native task id
- **THEN** OpenHUB keeps them distinct by runtime-qualified identity

#### Scenario: Child usage attribution

- **WHEN** a runtime reports child or delegated task lineage
- **THEN** Pulse adds its usage to the root task total and still permits child
  inspection without presenting the child as an unrelated top-level task

### Requirement: Task controls are real and capability-aware

OpenHUB SHALL invoke the owning runtime's pause, resume and open primitives and
SHALL NOT simulate success for an unsupported action.

#### Scenario: Action unsupported

- **WHEN** a runtime or task does not support a requested action
- **THEN** the API returns an explicit unsupported capability without mutating
  any task state

### Requirement: Transient stream disconnects are reconciled

OpenHUB SHALL keep a task in reconnecting state for up to 20 seconds after a
stream disconnect and SHALL refresh durable sequence and usage state before
declaring recovery.

#### Scenario: Stream resumes inside grace period

- **WHEN** the live stream resumes within 20 seconds
- **THEN** missed task and token deltas are backfilled and no user-visible
  terminal error is emitted

#### Scenario: Grace period expires

- **WHEN** neither the stream nor durable runtime state recovers within 20
  seconds
- **THEN** Pulse reports a degraded/error state with the last verified data
