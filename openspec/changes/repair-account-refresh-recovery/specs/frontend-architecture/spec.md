## ADDED Requirements

### Requirement: Accounts destination refreshes live quota without blocking cached render

The native Windows client SHALL render cached account summaries first and SHALL
request live account usage when the operator enters the Accounts destination.
The live request MUST reuse the controller's existing single-flight refresh so
startup, navigation, and manual refresh cannot create duplicate concurrent
refresh operations. Synthetic performance fixtures MUST NOT call the live
backend.

#### Scenario: Operator opens Accounts after startup

- **GIVEN** cached account rows are available
- **WHEN** the operator selects Accounts
- **THEN** cached rows remain immediately usable
- **AND** the client requests live account usage in the background
- **AND** successful rows are replaced with current quota evidence

#### Scenario: Startup refresh is already running

- **GIVEN** startup already began a live account usage refresh
- **WHEN** the operator selects Accounts before it finishes
- **THEN** the destination joins the same in-flight refresh
- **AND** no duplicate backend refresh request is created
