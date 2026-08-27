# multi-runtime-control Specification

## Purpose
TBD - created by archiving change evolve-openhub-multi-runtime-control. Update Purpose after archive.

## Requirements

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

### Requirement: Provider selection stays runtime-native

OpenHUB SHALL report the provider and model observed for each task but SHALL NOT
package a provider adapter or expose a Codex provider-profile switcher.

#### Scenario: Operator opens Pulse

- **WHEN** OpenHUB renders runtime status and task activity
- **THEN** it shows Codex, Hermes, and OpenCode health, model, provider, and
  usage evidence without an Ox bridge panel or provider-switch action

### Requirement: Transient disconnects are reconciled

OpenHUB SHALL preserve the last verified state for a 20-second reconnect grace
period and SHALL reconcile durable state and usage before recovery is declared.

#### Scenario: Runtime recovers inside grace

- **WHEN** the adapter or stream recovers within 20 seconds
- **THEN** missed deltas are backfilled and no terminal error is shown

#### Scenario: Grace expires

- **WHEN** live and durable state remain unavailable after 20 seconds
- **THEN** Pulse shows degraded/error with the last verified data

### Requirement: Pulse usage windows count post-start task activity exactly once

Pulse SHALL establish a zero historical baseline per available runtime and
SHALL count all usage first reported by a task created after that baseline in
the runtime's one-minute, one-hour, and since-start windows.

#### Scenario: Existing tasks are sampled when OpenHUB starts

- **WHEN** a runtime's first available snapshot contains existing tasks
- **THEN** their accumulated historical totals establish the zero baseline
- **AND** do not appear as usage since OpenHUB started

#### Scenario: A task is created after the runtime baseline

- **WHEN** a new runtime-qualified task first appears after that runtime has an
  available baseline
- **THEN** its current token total is counted once in the since-start window
- **AND** in the one-minute and one-hour windows for that observation time

#### Scenario: Runtime was unavailable at startup

- **WHEN** a runtime first becomes available after OpenHUB has already started
- **THEN** its existing tasks establish that runtime's baseline
- **AND** historical usage is not retroactively counted as current traffic
