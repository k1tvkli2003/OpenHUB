## ADDED Requirements

### Requirement: Free subscriptions are never routing candidates

The canonical account selector and managed Codex launch selector MUST exclude
every account whose plan is explicitly in the Free plan family. This hard gate
MUST apply before ranking, sticky fallback, preferred or pinned selection,
single-account routing, health recovery, additional-quota bypass, manual Codex
launch, and transient retry. The gate MUST NOT pause, delete, deactivate, or
rewrite the account, so a later paid-plan refresh can make it eligible again.

#### Scenario: Higher-quota Free account cannot win

- **GIVEN** an active Free account reports more remaining quota than an active
  eligible paid account
- **WHEN** Smart API or Auto Route selects an account
- **THEN** the paid account is selected
- **AND** the Free account is absent from the candidate pool

#### Scenario: Manual Free launch is refused

- **GIVEN** an operator explicitly requests a managed Codex launch with a Free
  account
- **WHEN** launch preparation validates that account
- **THEN** no managed route is prepared for the account
- **AND** the response reports a stable Free-plan exclusion reason

#### Scenario: Free-only pool has no route

- **GIVEN** every otherwise active account has a Free-family plan
- **WHEN** any routing strategy selects an account
- **THEN** no account is returned
- **AND** neither quota bypass nor transient fallback admits a Free account
