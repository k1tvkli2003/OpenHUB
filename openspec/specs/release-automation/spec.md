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

### Requirement: Release verification is fail-fast and version-invariant

Every external lint, test, and build command in the Windows release gate SHALL
stop the job immediately when it returns a non-zero exit code. Packaging,
upload, tag creation, release publication, and provenance attestation MUST NOT
run after any failed verification command.

Native compatibility tests SHALL derive the expected backend version from the
release-patched compatibility constant rather than a hard-coded stable version,
so prerelease and stable builds verify the same protocol boundary.

#### Scenario: A prerelease native test fails

- **WHEN** an ephemeral alpha, beta, or RC version is applied and any native
  verification command exits non-zero
- **THEN** the release job fails at that command
- **AND** no package, tag, GitHub release, or attestation is created

#### Scenario: A protocol fixture represents the current sidecar

- **WHEN** native protocol tests run after an ephemeral release version is
  applied
- **THEN** the fixture reports the current release-patched compatible backend
  version
- **AND** the test reaches the managed-route protocol assertion
