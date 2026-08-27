## ADDED Requirements

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
