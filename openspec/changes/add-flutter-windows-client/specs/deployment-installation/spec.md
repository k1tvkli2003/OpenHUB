# deployment-installation Delta

## ADDED Requirements

### Requirement: Local Windows native launch is version-pinned

The native Windows launch path MUST start an exact bundled or explicitly configured local backend artifact and MUST NOT use `uvx --upgrade`, a floating package constraint, or a Git remote during normal startup. Existing openhub data-directory resolution MUST remain unchanged unless the operator explicitly selects another local directory.

#### Scenario: Native app starts the local backend

- **GIVEN** no compatible backend is already listening
- **WHEN** the operator launches the native Windows application
- **THEN** it starts the pinned local backend on loopback
- **AND** the backend resolves the existing local data directory
- **AND** startup performs no package upgrade, Git fetch, push, or remote resolution

### Requirement: Installed managed-Codex shortcut carries launch intent

The local installer MUST create a stable Windows shortcut whose target resolves the current pinned OpenHUB package and passes explicit managed-launch intent to the native executable. The shortcut MUST continue to work after a local package version changes by resolving the installed current-version pointer and MUST perform no network update or repository operation.

#### Scenario: Current local package changes

- **GIVEN** a new verified OpenHUB package becomes the installed current version
- **WHEN** the operator invokes the stable managed-Codex shortcut
- **THEN** the shortcut starts that exact local version with managed-launch intent
- **AND** no floating package, Git remote, or network resolver is consulted

### Requirement: Managed Codex launch is process-scoped and credential-free

Managed launch MUST retain Codex's built-in provider and existing data home. It MAY set only a process-scoped, fixed loopback base URL for the exact new desktop process after confirming that the installed build supports that override. It MUST NOT embed an account token, refresh token, encryption key, or selected account identifier, and it MUST NOT edit Codex configuration or authentication material.

#### Scenario: OpenHUB prepares the next launch after integration

- **GIVEN** managed routing is enabled and the installed desktop capability is verified
- **WHEN** OpenHUB selects the best eligible account before opening Codex
- **THEN** no Codex OAuth flow is started
- **AND** `auth.json` is not read or written by the switch
- **AND** the launched process keeps the existing Codex home and built-in provider
- **AND** Codex configuration and data remain unchanged
