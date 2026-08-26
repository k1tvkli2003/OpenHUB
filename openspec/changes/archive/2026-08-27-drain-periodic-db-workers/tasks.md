## 1. Implementation

- [x] 1.1 Add a cancellation-safe cooperative periodic-task stop helper.
- [x] 1.2 Use it for cache-invalidation polling.
- [x] 1.3 Make bridge-ring registration, retry waits, and heartbeat waits stop-event driven.

## 2. Tests

- [x] 2.1 Prove cooperative stop does not cancel in-flight resource work.
- [x] 2.2 Prove the cache poller awaits its active iteration.
- [x] 2.3 Run the full websocket integration file with thread warnings promoted to errors.

## 3. Validation

- [x] 3.1 Run focused tests and Ruff.
- [x] 3.2 Validate the OpenSpec delta strictly.
