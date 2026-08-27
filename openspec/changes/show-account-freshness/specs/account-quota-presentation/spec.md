## ADDED Requirements

### Requirement: Account rows disclose source freshness

Every account row MUST display when its latest quota sample was recorded. The
account detail MUST distinguish the latest quota sample from the last credential
refresh and MUST expose an exact local timestamp for both when present.

#### Scenario: Usage and credential timestamps differ

- **GIVEN** an account has a quota sample and a credential refresh timestamp
- **WHEN** the operator views the account list or detail
- **THEN** the quota sample time is labeled as usage data
- **AND** the credential refresh time is labeled separately
- **AND** neither timestamp is presented as proof that the other source is fresh
