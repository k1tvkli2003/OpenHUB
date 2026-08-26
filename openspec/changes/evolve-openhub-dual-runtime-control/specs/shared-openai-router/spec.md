## ADDED Requirements

### Requirement: The account pool is client-neutral

OpenHUB SHALL expose one loopback-only OpenAI-compatible endpoint usable by
Codex and Hermes without a client restart when account rotation occurs.

#### Scenario: Independent parallel tasks

- **WHEN** multiple Codex and Hermes tasks send requests concurrently
- **THEN** independent requests may execute concurrently up to configured
  account and overload limits and are not serialized behind a global lock

#### Scenario: One account is rate limited

- **WHEN** an upstream account returns a retryable rate-limit or capacity error
- **THEN** only that account is cooled down and the request rotates to the next
  eligible account at most once in that routing round

#### Scenario: Continuation cannot be replayed safely

- **WHEN** a provider-owned continuation is pinned to an account
- **THEN** OpenHUB preserves that conversation's pin without blocking unrelated
  requests or silently replaying file/provider state on another account
