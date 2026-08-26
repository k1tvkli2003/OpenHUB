# frontend-architecture Delta

## ADDED Requirements

### Requirement: Native Windows client preserves the operator route inventory

Before it replaces the web dashboard for local Windows operation, the native client MUST provide the existing Dashboard, Reports, Accounts, APIs, Settings, and Automations destinations and preserve the permissions, confirmation boundaries, empty/loading/error states, and feature operations exposed by those destinations. Dashboard, Reports, Accounts, APIs, and Settings MUST remain core navigation; Automations MUST remain progressively disclosed as advanced navigation.

#### Scenario: Operator switches from web to native dashboard

- **GIVEN** an operator can access all six existing web destinations
- **WHEN** the native Windows client is designated as the primary local UI
- **THEN** every destination is reachable in the native navigation
- **AND** its parity-ledger operations have verified native equivalents
- **AND** the web compatibility UI is not removed before that verification completes

### Requirement: Native advanced settings are lazy

Native Settings MUST keep routing tuning, upstream proxy pools, model sources, firewall, quota planner, and sticky sessions in a collapsed Advanced group and MUST defer their network requests until the group or owning section is opened.

#### Scenario: Operator opens core Settings

- **WHEN** the native Settings destination first renders
- **THEN** core appearance, import, access, session, and API-key surfaces are available
- **AND** advanced settings endpoints have not been requested
- **AND** one explicit interaction reveals and loads the advanced group

### Requirement: Managed launch state has one canonical presentation

The current prepared Codex launch MUST have one canonical state in the native controller and typed API model. Accounts MAY expose candidate evidence and the current-process badge, while Overview and Settings MAY summarize that state, but every presentation MUST derive from the same launch snapshot and use the same freshness, exclusion, preparation, already-running, and launch-failure vocabulary.

#### Scenario: A managed launch is prepared

- **WHEN** the backend selects and verifies the top candidate
- **THEN** the account badge, Overview routing summary, and Settings integration status update from one launch snapshot
- **AND** no page maintains a competing local copy of the selected account or recomputes ranking in Dart
