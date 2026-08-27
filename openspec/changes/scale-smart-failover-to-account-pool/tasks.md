## 1. Contract

- [x] 1.1 Specify bounded full-pool pre-visible quota failover.
- [x] 1.2 Preserve deadline, ownership, and downstream-visibility boundaries.

## 2. Implementation

- [x] 2.1 Raise the shared distinct-account attempt budget for SSE, compact, and WebSocket paths.
- [x] 2.2 Add regressions that succeed only beyond the legacy two/three-account caps.

## 3. Verification

- [x] 3.1 Run focused endpoint and transport failover tests.
  - Evidence: 10 focused SSE, compact, WebSocket, transparent-replay, and visible-output boundary tests passed.
- [x] 3.2 Run the relevant proxy unit/integration suite.
  - Evidence: `tests/integration/test_proxy_transient_retry.py` passed 35/35; focused Ruff checks passed.
- [ ] 3.3 Run strict OpenSpec validation if the CLI is available locally.
  - Blocked locally: the `openspec` CLI is not installed or callable.
