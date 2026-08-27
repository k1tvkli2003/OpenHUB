## ADDED Requirements

### Requirement: Standalone OpenHUB documentation set

The public repository MUST provide a concise root README and linked documents
covering installation, profile/account/provider concepts, OpenAI pool failover,
Ox setup, task hierarchy and lifecycle semantics, architecture, security and
credential boundaries, troubleshooting, development, and release verification.
Feature documents MUST link to their owning OpenSpec capability.

#### Scenario: New user installs without the developer's machine

- **WHEN** a new user follows the public installation and profile guide
- **THEN** every required path is expressed as a discovery rule or placeholder
- **AND** no step assumes the original developer's username, drive, account, or
  preinstalled external switcher
