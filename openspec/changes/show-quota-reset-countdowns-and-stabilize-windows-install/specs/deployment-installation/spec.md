## ADDED Requirements

### Requirement: Native Windows installation uses one stable Program Files layout

The local installer SHALL place the current OpenHUB application at
`C:\Program Files\OpenHUB\App` and retain the current validated release artifact
at `C:\Program Files\OpenHUB\Release`. Desktop and Start Menu shortcuts SHALL
resolve the stable installed executable instead of a timestamped package or
current-version pointer. Automatic startup SHALL remain disabled.

#### Scenario: A new local build is installed

- **WHEN** package validation and staged installation succeed
- **THEN** `App\OpenHUB.exe` is the only installed application version
- **AND** the retained Release artifact identifies the same build
- **AND** every OpenHUB shortcut targets the stable executable or its stable managed-launch form

#### Scenario: Installation fails before the swap

- **WHEN** package validation or staged copy fails
- **THEN** the prior App directory remains usable
- **AND** partial staging content is removed
- **AND** no shortcut is updated to an incomplete application

#### Scenario: Superseded local packages exist

- **GIVEN** the new fixed-layout installation has completed successfully
- **WHEN** cleanup runs
- **THEN** superseded OpenHUB package directories and release artifacts are removed
- **AND** disabled-startup preservation data and user-owned Codex data remain untouched
