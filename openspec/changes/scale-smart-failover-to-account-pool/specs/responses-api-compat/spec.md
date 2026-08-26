## ADDED Requirements

### Requirement: Replay-safe quota failover traverses the managed account pool

For SSE, compact HTTP, and WebSocket Responses requests, the proxy MUST continue
selecting distinct eligible accounts after recognized pre-visible quota failures
until an account succeeds, no eligible account remains, the request deadline is
exhausted, or the defensive sixteen-account attempt cap is reached. Each failed
account MUST be excluded from later attempts for that request. The proxy MUST NOT
forward a failed account's quota error when a later account completes the same
request successfully.

#### Scenario: Healthy account exists beyond the legacy stream cap

- **GIVEN** at least four eligible accounts for a replay-safe Responses request
- **AND** the first three selected accounts return a recognized quota failure before any downstream-visible output
- **WHEN** the fourth selected account completes within the request deadline
- **THEN** the client receives one successful response from the fourth account
- **AND** the client receives no quota failure from the first three accounts
- **AND** each failed account is excluded from the remaining selection loop

#### Scenario: Visible output preserves the no-replay boundary

- **GIVEN** an account has emitted downstream-visible response output
- **WHEN** that account subsequently returns a quota failure
- **THEN** the proxy MUST NOT replay the request on another account
- **AND** the existing terminal error behavior remains in effect

#### Scenario: Hard ownership remains fail-closed

- **GIVEN** a request is pinned to an account by file ownership or required response continuity
- **WHEN** the owner returns a quota failure
- **THEN** the proxy MUST NOT move the request to another account merely because the larger attempt budget is available
