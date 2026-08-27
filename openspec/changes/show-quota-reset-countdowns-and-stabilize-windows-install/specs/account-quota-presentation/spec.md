## ADDED Requirements

### Requirement: Account rows expose live quota-reset timing

Every native Windows account row SHALL expose the remaining time until every
reported quota-window reset in the expanded layout. Compact and dense layouts
SHALL expose the earliest reported reset. Reset timing SHALL be visually
distinct from remaining-usage percentage, readable without opening the account
inspector, and derived only from the account summary timestamps and local clock.

#### Scenario: Account reports multiple quota windows

- **GIVEN** an account reports primary and secondary reset timestamps
- **WHEN** its expanded account row is visible
- **THEN** the row shows both countdowns with distinct window labels
- **AND** hovering or focusing the indicator exposes each exact reset timestamp

#### Scenario: Account row is compact or dense

- **GIVEN** an account reports more than one future reset timestamp
- **WHEN** responsive width or pool size selects a compact presentation
- **THEN** the row shows the earliest reported reset with its window label
- **AND** the value remains readable without increasing network activity

#### Scenario: Reset time is missing or elapsed

- **GIVEN** no reset timestamp is reported, or the reported timestamp has elapsed
- **WHEN** the indicator renders
- **THEN** it displays an explicit `Not reported` or `Due now` state
- **AND** it does not infer a replacement timestamp

### Requirement: Countdown updates are lifecycle-safe

The Accounts page SHALL use one owned countdown clock for visible rows. The
clock SHALL be disposed with the page, SHALL NOT create one timer per account,
and SHALL NOT trigger account refresh or any other network request.

#### Scenario: A minute boundary passes while Accounts is open

- **WHEN** the shared clock advances
- **THEN** visible countdown text updates from the existing account timestamps
- **AND** no account refresh request is emitted

### Requirement: Writable startup refreshes account quota automatically

After the local backend and authenticated writable dashboard session are ready,
OpenHUB SHALL hydrate the initial cached account list and then automatically
start one account-usage refresh. The live refresh SHALL NOT require an operator
click and SHALL NOT block the remaining dashboard startup. Guest or read-only
sessions SHALL NOT attempt the write-protected refresh.

#### Scenario: OpenHUB opens with a writable local session

- **WHEN** backend readiness, authentication, and initial core hydration finish
- **THEN** account usage refresh starts automatically
- **AND** cached account rows remain usable while the refresh is running
- **AND** per-account success or failure states are updated by the existing refresh result handling
