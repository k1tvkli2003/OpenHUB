## ADDED Requirements

### Requirement: One normalized task surface covers three runtimes

OpenHUB SHALL expose Codex, Hermes, and OpenCode tasks through one normalized
schema preserving runtime-qualified identity, root/parent lineage, lifecycle,
provider, model, activity, usage counters, health, and supported actions.

#### Scenario: Native ids collide

- **WHEN** two runtimes report the same native task id
- **THEN** OpenHUB keeps them distinct with runtime-qualified ids

#### Scenario: Child usage attribution

- **WHEN** a runtime reports a child or delegated task
- **THEN** Pulse attributes its usage to the root task total and retains the
  child as inspectable lineage rather than an unrelated top-level task

### Requirement: Controls are native and capability-aware

OpenHUB SHALL call a verified primitive owned by the task's runtime and SHALL
return an explicit unsupported result when no such primitive exists.

#### Scenario: Pause is not natively persistent

- **WHEN** the selected runtime can interrupt or stop but cannot persistently
  pause one task
- **THEN** Pulse disables pause for that task and does not simulate success

### Requirement: Transient disconnects are reconciled

OpenHUB SHALL preserve the last verified state for a 20-second reconnect grace
period and SHALL reconcile durable state and usage before recovery is declared.

#### Scenario: Runtime recovers inside grace

- **WHEN** the adapter or stream recovers within 20 seconds
- **THEN** missed deltas are backfilled and no terminal error is shown

#### Scenario: Grace expires

- **WHEN** live and durable state remain unavailable after 20 seconds
- **THEN** Pulse shows degraded/error with the last verified data
