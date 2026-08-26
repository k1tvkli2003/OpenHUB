# release-automation Specification

## Purpose

Define least-privilege GitHub automation for OpenHUB validation and Windows
publication.

## Requirements

### Requirement: CI covers every shipped surface

Pull requests and `main` pushes SHALL lint and test the Python backend, lint,
type-check, test, and build the browser dashboard, analyze, test, and compile
the native Windows client, validate the Helm chart against supported Kubernetes
versions, smoke-install the chart in kind, and strictly validate shipped
OpenSpec contracts.

#### Scenario: A pull request changes shared code

- **WHEN** CI runs for the pull request
- **THEN** backend, dashboard, native Windows, Helm, and contract jobs each
  report an explicit result

### Requirement: External actions are immutable

Every third-party `uses:` reference in CI and release workflows SHALL be pinned
to a full 40-character commit SHA. Workflow-level permissions SHALL default to
read-only and publication write/identity permissions SHALL exist only on the
release publication job.

#### Scenario: Workflow dependency is reviewed

- **WHEN** a reviewer inspects an external action invocation
- **THEN** its exact source commit and the narrow job permissions are visible
  in the workflow

### Requirement: Release inputs never contain credentials

Provider and repository credentials SHALL remain in their owning stores or
GitHub token context. Release scripts MUST NOT pass a secret through a command
argument, generated package, checksum, SBOM, or log.

#### Scenario: GitHub Release is published

- **WHEN** the publication job calls the GitHub CLI
- **THEN** authentication is supplied by the process environment
- **AND** no credential value appears in the command arguments or release
  assets
