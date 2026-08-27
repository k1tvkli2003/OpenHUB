## ADDED Requirements

### Requirement: Codex knowledge is copied selectively into Hermes

OpenHUB SHALL copy global agent instructions, durable memories and user-authored
skill sources into Hermes while leaving Codex sources in place.

#### Scenario: Generated dependency bulk exists

- **WHEN** a skill contains caches, virtual environments, dependency trees,
  logs, temporary data or build output
- **THEN** the copy excludes that bulk and records each exclusion class in the
  manifest

#### Scenario: Destination conflict

- **WHEN** a destination path exists with different content
- **THEN** OpenHUB skips the conflict and reports it without overwriting either
  copy

#### Scenario: Sensitive source exists

- **WHEN** credentials, auth stores or secret-bearing MCP configuration exist
  under the Codex home
- **THEN** they are neither read for content import nor copied to Hermes
