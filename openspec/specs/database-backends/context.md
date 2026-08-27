## Overview

openhub is designed to be SQLite-first for simple local usage and container defaults. SQLite-specific resilience behavior (integrity checks, WAL tuning, recovery tooling) remains valuable for the default mode.

For higher concurrency or infrastructure-managed deployments, PostgreSQL support is enabled through SQLAlchemy async URLs using `asyncpg`.

## Decisions

- Keep SQLite as default to preserve zero-config startup.
- Accept PostgreSQL through `OPENHUB_DATABASE_URL` only; no new configuration key aliases.
- Keep SQLite-specific recovery tooling SQLite-only; PostgreSQL operations should use PostgreSQL-native backup/recovery practices.
- Default SQLite startup validation to `quick` so normal boots stay fast while operators can still opt into `full` or `off`.

## Operational Notes

- SQLite default URL: `sqlite+aiosqlite:///~/.openhub/store.db`
- SQLite startup check mode: `OPENHUB_DATABASE_SQLITE_STARTUP_CHECK_MODE=quick|full|off` (default `quick`)
- PostgreSQL example URL: `postgresql+asyncpg://openhub:openhub@127.0.0.1:5432/openhub`
- Pool sizing (`database_pool_size`, `database_max_overflow`) applies to PostgreSQL engine creation; the pool checkout timeout (30 s) and connection recycle window (1800 s) are fixed constants in `app/db/session.py` (issue #1340 phase 3).
- The background/request-adjacent DB engine always derives its pool sizing from `database_pool_size` and `database_max_overflow`; it isolates background-task checkouts rather than being sized independently.
- Periodic DB workers use cooperative stop events. Cancelling an aiosqlite
  connection acquisition can leave its worker trying to resolve a future after
  the event loop has closed, so shutdown wakes interval waits and awaits the
  current DB iteration instead. This applies to the cache-invalidation poller
  and bridge-ring heartbeat. A worker already between polls exits immediately;
  a worker inside a query first closes its short-lived session.

## Example

Use PostgreSQL while keeping all other defaults:

```bash
OPENHUB_DATABASE_URL=postgresql+asyncpg://openhub:openhub@127.0.0.1:5432/openhub openhub
```

Use SQLite with explicit full startup validation:

```bash
OPENHUB_DATABASE_SQLITE_STARTUP_CHECK_MODE=full openhub
```
