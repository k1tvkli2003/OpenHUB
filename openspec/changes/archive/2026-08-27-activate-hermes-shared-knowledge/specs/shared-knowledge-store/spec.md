## ADDED Requirements

### Requirement: Applied Hermes federation activates its managed loader

When an operator applies shared-knowledge federation, OpenHUB SHALL explicitly
enable the managed `openhub-shared-knowledge` Hermes plugin so that current
Hermes opt-in plugin loading injects canonical instructions and memory into new
agent turns.

#### Scenario: Installed plugin was not previously enabled

- **WHEN** federation is applied and the managed plugin is absent from
  `plugins.enabled`
- **THEN** OpenHUB adds the managed plugin id to `plugins.enabled`
- **AND** a fresh Hermes process loads the plugin

#### Scenario: Managed plugin was explicitly disabled

- **WHEN** federation is applied and the managed plugin appears in
  `plugins.disabled`
- **THEN** OpenHUB removes only the managed plugin id from `plugins.disabled`
- **AND** preserves every unrelated disabled plugin

#### Scenario: Existing plugin choices are present

- **WHEN** Hermes already has unrelated enabled or disabled plugins
- **THEN** applying federation preserves those choices unchanged

#### Scenario: Federation is a dry run

- **WHEN** federation is evaluated without apply confirmation
- **THEN** Hermes plugin activation state is not changed
