# release-management Specification

## Purpose

Define reproducible, monotonic OpenHUB Windows releases whose source identity,
version, integrity metadata, and publication state remain auditable.

## Requirements

### Requirement: Every accepted main revision receives a unique beta release

The Windows release workflow SHALL run for every push to `main`. It SHALL derive
`X.Y.Z-beta.N` from the source release train and the monotonically increasing
GitHub run number. Release runs SHALL be serialized and SHALL NOT cancel an
in-progress run.

#### Scenario: Two main pushes arrive close together

- **WHEN** a second `main` push arrives while the prior release is building
- **THEN** the second release waits rather than cancelling the first
- **AND** each revision receives a different beta tag

### Requirement: Manual releases accept only canonical versions

A manual release SHALL accept only `X.Y.Z` or
`X.Y.Z-(alpha|beta|rc).N`. The requested version SHALL be applied ephemerally
to every release-managed source field before build and SHALL NOT require a
version-bump commit.

#### Scenario: Invalid manual version

- **WHEN** a maintainer requests a non-canonical release version
- **THEN** metadata validation fails before dependencies, packaging, tagging,
  or publication

### Requirement: Windows artifacts are reproducible and integrity-described

The release SHALL build the Flutter Windows client and pinned Python backend
from the exact workflow commit. It SHALL publish the portable ZIP, an external
SHA-256 checksum file, an SPDX JSON SBOM, and a GitHub build-provenance
attestation. The package SHALL also contain per-file SHA-256 hashes.

#### Scenario: Release payload is built

- **WHEN** backend and native verification pass
- **THEN** the published payload contains the Windows ZIP, `SHA256SUMS.txt`,
  and SPDX SBOM
- **AND** provenance identifies the workflow commit that produced the ZIP

### Requirement: Tags are immutable and reruns are idempotent

The publication job SHALL create a missing release tag at the workflow commit,
SHALL reject a tag that already targets another commit, and MAY replace assets
only when an existing tag targets the same commit.

#### Scenario: Existing tag targets another revision

- **WHEN** a release tag already resolves to a different commit
- **THEN** publication fails without moving or deleting that tag

#### Scenario: Same workflow is rerun

- **WHEN** the tag and release already target the workflow commit
- **THEN** verified assets are refreshed without creating a second tag or
  release

### Requirement: Signing claims match actual evidence

OpenHUB SHALL document Windows artifacts as unsigned until Authenticode signing
and certificate verification exist in the release workflow. Checksums and
GitHub provenance MUST NOT be described as Windows code signing.

#### Scenario: Unsigned public package

- **WHEN** a user reads installation or release documentation
- **THEN** the documentation identifies checksum/SBOM/provenance evidence and
  plainly states that the binary is unsigned

