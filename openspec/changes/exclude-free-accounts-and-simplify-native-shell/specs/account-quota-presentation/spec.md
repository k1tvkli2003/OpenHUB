## ADDED Requirements

### Requirement: Native account presentation marks Free plans unavailable

The native Accounts screen MUST place an explicitly Free account in the
unavailable group regardless of its cached or current remaining percentage.
The row and account detail MUST explain that Free subscriptions are retained
locally but excluded from Smart API, Auto Route, Next Route, and manual Codex
launch. Every launch control for that account MUST be disabled.

#### Scenario: Fresh Free account stays outside Next Route

- **GIVEN** an active Free account refreshed successfully in the current HUB
  session and reports remaining quota
- **WHEN** the Accounts screen renders
- **THEN** the account appears under the unavailable group with a Free-plan
  routing-exclusion state
- **AND** it is absent from Next Route
- **AND** its manual launch controls are disabled
