## ADDED Requirements

### Requirement: Managed OpenAI pool fails over automatically

An automatic OpenHUB OpenAI Pool launch MUST treat its prepared account as a
soft initial preference. After account-scoped rate-limit, transient capacity,
or recoverable authentication failure, retry-safe work MUST exclude that account
and select another registered usable account without restarting Codex or
returning the intermediate upstream error to the client. Manual selection and
continuity-required file work MUST remain hard pinned unless canonical replay
proof explicitly permits migration.

#### Scenario: Automatically selected account is rate limited

- **GIVEN** automatic managed launch initially selects account A
- **AND** account B is registered and usable
- **WHEN** upstream rate-limits retry-safe work on account A
- **THEN** account A is excluded for the retry and account B serves the work
- **AND** Codex remains on the same local endpoint and process

#### Scenario: Manual account is exhausted

- **GIVEN** the operator manually prepared account A
- **WHEN** account A is exhausted
- **THEN** the proxy fails with a bounded pinned-route error
- **AND** it does not silently use account B

#### Scenario: File continuity prevents account migration

- **GIVEN** a response continuation requires a file owned by account A
- **WHEN** account A becomes unavailable
- **THEN** the proxy fails closed with continuity evidence
- **AND** it does not forward the file-backed request through another account
