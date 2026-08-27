## ADDED Requirements

### Requirement: Soft prompt-cache recovery contention preserves pool liveness

When concurrent first-turn requests share a soft prompt-cache key and one request
reserves a due recovery probe, sibling requests MUST select from other eligible
healthy accounts instead of returning global pool exhaustion. At most one request
MAY hold the recovery reservation, and hard continuity-owner restrictions MUST
remain fail-closed.

#### Scenario: Concurrent soft requests share a recovery candidate

- **GIVEN** a healthy account and a due probing account are eligible
- **AND** multiple first-turn requests share one prompt-cache key
- **WHEN** one request reserves the probing account
- **THEN** sibling requests select an eligible healthy account
- **AND** only one request persists or consumes the recovery probe admission

### Requirement: Recovery state races refresh selection inputs

When account-state persistence commits a recovery transition or loses its CAS
to another request, the selector MUST invalidate cached account inputs before a
bounded retry can reuse them.

#### Scenario: Concurrent recovery CAS changes the stored account row

- **GIVEN** selection inputs contain a pre-recovery account snapshot
- **WHEN** one request commits recovery or another request observes a CAS miss
- **THEN** the cached snapshot is invalidated
- **AND** the next selection attempt reloads current account state
