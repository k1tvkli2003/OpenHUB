## ADDED Requirements

### Requirement: Root task pause is persistent and interrupting

Pausing a root task MUST set its existing goal status to `paused` without
replacing the objective or resetting usage and MUST interrupt every in-progress
turn in the root and descendants. The operation MUST report partial failures and
MUST NOT represent a local UI flag as a successful pause.

#### Scenario: Goal task with active descendants is paused

- **WHEN** the operator pauses an active root with two active descendants
- **THEN** the root goal status becomes `paused`
- **AND** all three in-progress turns finish as interrupted
- **AND** the UI reports success only after server acknowledgements

### Requirement: Resume preserves persisted context

Resuming a paused goal task MUST reconnect to the same root thread and restore
its goal status to `active` without replacing the objective or usage. For a
non-goal interrupted task, OpenHUB SHALL expose a distinct Continue action that
resumes the same thread and starts one bounded continuation turn; it MUST NOT
claim to resurrect the already interrupted turn.

#### Scenario: Paused goal resumes

- **WHEN** the operator resumes a root whose persisted goal is paused
- **THEN** app-server returns the same root thread id and active goal state
- **AND** existing history and files remain referenced in place

#### Scenario: Non-goal task cannot resume an interrupted turn

- **WHEN** the operator continues a paused non-goal task
- **THEN** OpenHUB labels the action Continue and creates a new continuation
  turn on the same thread
- **AND** it does not label the prior interrupted turn in progress
