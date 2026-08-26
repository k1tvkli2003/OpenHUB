## ADDED Requirements

### Requirement: Constellation layout remains responsive and virtualized

The native Accounts page MUST use responsive layout constraints rather than
fixed screen coordinates. At wide widths the account constellation and Next
route rail MAY appear side by side; at narrow widths the route rail and selected
inspector MUST stack without horizontal overflow. The account collection MUST
remain virtualized for large pools.

#### Scenario: Operator resizes the Windows app

- **GIVEN** the Accounts page is visible
- **WHEN** the available content width crosses a layout breakpoint
- **THEN** the route rail changes between side-by-side and stacked placement
- **AND** account actions remain reachable
- **AND** account rows are still built lazily
