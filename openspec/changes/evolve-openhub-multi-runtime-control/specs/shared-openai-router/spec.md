## ADDED Requirements

### Requirement: The account pool is runtime-neutral

OpenHUB SHALL expose one numeric-loopback OpenAI-compatible endpoint usable by
Codex, Hermes, and OpenCode without restarting a client when account rotation
occurs.

#### Scenario: Independent parallel tasks

- **WHEN** multiple tasks from any combination of the three runtimes submit
  requests concurrently
- **THEN** requests execute independently up to configured account and overload
  limits and are not serialized behind a global lock

#### Scenario: One account is rate limited

- **WHEN** an upstream account returns a retryable rate-limit or capacity error
- **THEN** only that account is cooled down and the request rotates to another
  eligible account at most once in that routing round

#### Scenario: Continuation cannot be replayed safely

- **WHEN** provider-owned continuation state is pinned to one account
- **THEN** OpenHUB preserves that conversation affinity without blocking
  unrelated requests or transferring provider/file state to another account
