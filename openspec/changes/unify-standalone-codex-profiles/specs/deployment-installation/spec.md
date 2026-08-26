## ADDED Requirements

### Requirement: Standalone portable Windows package

The Windows package MUST resolve application assets relative to its installation
and user data roots and MUST NOT embed the packager's home directory. It SHALL
include or deterministically acquire every runtime required by the shipped Ox
profile and SHALL preserve existing user data during install or upgrade.

#### Scenario: Another user installs the public archive

- **WHEN** the release is installed under a different Windows account and path
- **THEN** OpenHUB discovers Codex and uses installation-relative Ox assets
- **AND** no request references the original developer's drive or username

### Requirement: Honest unsigned artifact state

Until a real Authenticode identity is configured, release documentation and
metadata MUST identify the Windows artifacts as unsigned and MUST NOT claim
SmartScreen trust or publisher verification.

#### Scenario: First public release has no certificate

- **WHEN** `v0.1.0` is published without signing credentials
- **THEN** build and release succeed with unsigned artifacts
- **AND** release notes explain hash verification and the unsigned boundary
