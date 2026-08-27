## ADDED Requirements

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
