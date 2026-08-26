## ADDED Requirements

### Requirement: Native shell is account-first without Overview

The native Windows shell MUST use Accounts as its initial destination and MUST
NOT expose an Overview destination. Accounts, Traffic, API access, Automations,
and Settings MUST remain reachable from top-level navigation.

Overview-owned functions MUST be relocated instead of silently removed:
account readiness belongs in Accounts; live capacity, routing projections,
request attribution, and aggregate analytics belong in Traffic; Auto Route and
normal Codex launch controls belong in Settings.

#### Scenario: App opens into the account pool

- **WHEN** an authenticated operator opens OpenHUB
- **THEN** Accounts is the selected top-level destination
- **AND** no Overview navigation item exists
- **AND** Traffic and Settings expose the relocated operational surfaces

### Requirement: Accounts prioritizes the virtualized list

The native Accounts screen MUST render a compact horizontal Next Route strip
above a full-height virtualized account list. It MUST NOT reserve a permanent
side route rail or bottom selected-account inspector. Account management and
manual launch MUST remain directly reachable from every row.

#### Scenario: Normal desktop height shows a useful account set

- **GIVEN** a 1280 by 900 native window with at least five accounts
- **WHEN** Accounts renders
- **THEN** the account list receives the dominant remaining height
- **AND** at least four complete account rows are visible before scrolling
- **AND** management and launch controls remain reachable without a permanent
  inspector
