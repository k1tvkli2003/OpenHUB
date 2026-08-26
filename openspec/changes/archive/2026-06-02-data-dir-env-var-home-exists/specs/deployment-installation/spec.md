## ADDED Requirements

### Requirement: Application data directory resolution is configurable and container-aware

The application MUST resolve its default data directory from operator intent before container heuristics. A non-empty `OPENHUB_DATA_DIR` value MUST be the highest-priority data directory override. When no override is configured, an existing `$HOME/.openhub` directory MUST remain preferred even if the process detects that it is running inside a container. The container data directory (`/var/lib/openhub`) MUST be used only when no override is configured, the home data directory does not already exist, and container detection is true.

#### Scenario: Explicit data directory override wins

- **GIVEN** `OPENHUB_DATA_DIR` is configured to a non-empty path
- **WHEN** application settings are loaded
- **THEN** the configured path is used as the data directory
- **AND** the container detection result does not override it

#### Scenario: Existing home data is reused inside an interactive container

- **GIVEN** `OPENHUB_DATA_DIR` is not configured
- **AND** `$HOME/.openhub` already exists
- **AND** container detection is true
- **WHEN** application settings are loaded
- **THEN** `$HOME/.openhub` is used as the data directory
- **AND** `/var/lib/openhub` is not selected

#### Scenario: Container default is preserved when no home data exists

- **GIVEN** `OPENHUB_DATA_DIR` is not configured
- **AND** `$HOME/.openhub` does not exist
- **AND** container detection is true
- **WHEN** application settings are loaded
- **THEN** `/var/lib/openhub` is used as the data directory

#### Scenario: Related default paths follow the resolved data directory

- **GIVEN** the resolved data directory differs from the module-import default
- **AND** the database URL, encryption key file, conversation archive directory, and response-create dump directory are not explicitly configured
- **WHEN** application settings and proxy dump helpers are used
- **THEN** the default SQLite database URL points at `<data-dir>/store.db`
- **AND** the default encryption key file points at `<data-dir>/encryption.key`
- **AND** the default conversation archive directory points at `<data-dir>/conversation-archive`
- **AND** oversized response-create dumps are written under `<data-dir>/debug/response-create-dumps`

#### Scenario: Explicit related path overrides are preserved

- **GIVEN** `OPENHUB_DATA_DIR` is configured
- **AND** one or more related paths such as `OPENHUB_DATABASE_URL`, `OPENHUB_ENCRYPTION_KEY_FILE`, or `OPENHUB_CONVERSATION_ARCHIVE_DIR` are explicitly configured
- **WHEN** application settings are loaded
- **THEN** each explicitly configured related path keeps its configured value
- **AND** only omitted related paths derive from the resolved data directory
