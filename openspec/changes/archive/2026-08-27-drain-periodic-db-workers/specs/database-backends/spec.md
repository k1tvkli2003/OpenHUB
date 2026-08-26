## ADDED Requirements

### Requirement: Periodic database workers shut down without orphaning driver work

Event-driven periodic workers that can be inside an asynchronous database
operation MUST stop cooperatively. Shutdown MUST signal their stop event, allow
the current database iteration and session cleanup to finish, and await the
worker before closing the database engine or event loop. Shutdown MUST NOT
cancel an in-flight connection acquisition merely to interrupt the interval
wait.

#### Scenario: Cache poll is acquiring a SQLite connection during shutdown

- **GIVEN** the cache-invalidation poller is inside a database iteration
- **WHEN** application shutdown requests the poller to stop
- **THEN** the current iteration finishes and closes its session before the poller exits
- **AND** no aiosqlite worker attempts to report completion to a closed event loop

#### Scenario: Ring heartbeat is reading membership during shutdown

- **GIVEN** the bridge-ring heartbeat task is registering, heartbeating, or refreshing membership
- **WHEN** application shutdown requests the heartbeat task to stop
- **THEN** the current database operation finishes before the heartbeat task exits
- **AND** the periodic interval wait wakes immediately from the stop signal
