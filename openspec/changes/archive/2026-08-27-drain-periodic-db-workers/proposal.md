## Why

Repeated short-lived application lifespans exposed a shutdown race on Windows:
the cache-invalidation poller or bridge-ring heartbeat could be cancelled while
aiosqlite was acquiring a connection. The session never received that partial
connection, and its worker later attempted to resolve a future on an event loop
that had already closed.

## What Changes

- Stop periodic database workers through an event instead of cancelling their
  in-flight database operation.
- Wake interval and retry waits immediately when shutdown starts.
- Await current iteration cleanup before closing the database engine/event loop.

## Impact

- Removes orphaned SQLite worker threads and teardown warnings.
- Keeps normal heartbeat/poll cadence and cross-replica semantics unchanged.
- Shutdown may wait for the current bounded database operation to unwind rather
  than abandoning driver work.
