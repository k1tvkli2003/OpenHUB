## ADDED Requirements

### Requirement: Root task aggregation

Pulse MUST present one top-level task per app-server `sessionId`. Descendant
threads MUST appear only in an expandable hierarchy under that root. Each unique
thread's token total and positive rolling delta MUST contribute to its root
exactly once.

#### Scenario: Root owns two subagents

- **GIVEN** one root and two descendants share the same `sessionId`
- **WHEN** Pulse renders and totals usage
- **THEN** it displays one top-level task with two child entries
- **AND** the root total equals the sum of three unique thread counters without
  counting the root or either child twice

#### Scenario: App-server hierarchy is unavailable

- **WHEN** app-server cannot be reached but rollout session metadata is readable
- **THEN** Pulse groups by the persisted rollout `session_id` fallback
- **AND** marks hierarchy/control evidence degraded rather than guessing parent
  relationships
