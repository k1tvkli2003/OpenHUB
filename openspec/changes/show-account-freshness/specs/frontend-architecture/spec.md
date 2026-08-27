## ADDED Requirements

### Requirement: Freshness remains visible in the virtualized account list

The native account list MUST show source freshness without fetching per-account
detail data, expanding all rows, or disabling list virtualization.

#### Scenario: Operator scans many accounts

- **GIVEN** multiple account summaries are already loaded
- **WHEN** the accounts screen renders its virtualized list
- **THEN** each visible row shows quota sample and credential refresh age
- **AND** no per-row detail request is required
