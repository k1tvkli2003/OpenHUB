## ADDED Requirements

### Requirement: Reproducible OpenHUB GitHub release

Pushes to `main` and manual dispatch SHALL run least-privilege validation and
produce a versioned Windows x64 archive, installer, SHA-256 manifest, and SBOM.
Third-party Actions MUST be pinned to immutable commit SHAs. Release publication
MUST be blocked by failing specs, tests, build, secret scan, personal-path scan,
or package verification.

#### Scenario: Source contains a personal absolute path

- **WHEN** the release workflow finds a forbidden developer path in publishable
  source or packaged files
- **THEN** the workflow fails before creating or updating a GitHub release

#### Scenario: Valid main build completes

- **WHEN** main passes all release gates
- **THEN** the workflow publishes artifacts whose hashes match the manifest
- **AND** attaches build identity/SBOM evidence supported by the repository plan
