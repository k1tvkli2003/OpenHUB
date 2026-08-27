# public-product-identity Specification

## Purpose
TBD - created by archiving change reconcile-openhub-public-identity. Update Purpose after archive.

## Requirements

### Requirement: Active public surfaces use one truthful OpenHUB identity

Every active product, documentation, package, workflow, and release surface
owned by this repository SHALL use the OpenHUB name and approved visual system.
The approved hex-lightning logo MUST remain unchanged. A supplemental OpenHUB
wordmark MAY appear at sparse identity moments but MUST NOT replace operational
labels or reduce small-size legibility.

Historical archives, git history, third-party copyright notices, explicit
compatibility literals, and provenance acknowledgments MAY retain prior names
when their context makes clear that they are not the current product identity.

#### Scenario: A user opens GitHub Pages

- **WHEN** the deployed Pages home renders
- **THEN** its name, mark, favicon, capability summary, links, and screenshots
  describe this OpenHUB repository and current release
- **AND** no active image or copy presents the upstream product as OpenHUB

#### Scenario: A release is prepared

- **WHEN** release validation scans publishable source and packaged files
- **THEN** stale product branding and unsupported artifact locations fail the
  release before publication
- **AND** explicit license/provenance acknowledgments remain allowed

### Requirement: OAuth identity ownership is disclosed honestly

OpenHUB SHALL brand its locally controlled OAuth dialogs and completion page as
OpenHUB. Before opening browser or device authorization, it SHALL disclose that
OpenAI hosts the authorization surface under the official Codex OAuth client
identity and that OpenHUB receives the local callback. OpenHUB MUST NOT claim an
independently registered OpenAI OAuth application unless one is actually
configured and verified.

#### Scenario: Browser authorization starts

- **WHEN** a user selects browser sign-in
- **THEN** the OpenHUB dialog explains the provider-hosted Codex identity before
  opening the OpenAI page
- **AND** successful redirect completion renders the approved OpenHUB identity
  on the local callback page

### Requirement: Public install instructions reference published artifacts

Public install commands SHALL reference only artifacts that are built and
published by this repository, or shall explicitly use a local-from-source path.

#### Scenario: No public container or OCI chart exists

- **WHEN** documentation presents Docker or Helm setup
- **THEN** it uses a local image/chart build or a user-supplied image location
- **AND** it does not claim a GHCR/OCI package exists

### Requirement: Project contributors and upstream provenance are distinct

OpenHUB-owned contributor registries and the GitHub default-branch contributor
panel SHALL list only accounts that authored this OpenHUB repository. Imported
upstream authors MUST NOT be presented as direct OpenHUB contributors solely
because their commit graph was retained during project creation.

The README SHALL preserve explicit Codex LB license, provenance, and
contributor thanks separately. Contributor-history normalization MUST preserve
the complete tracked tree, immutable release tags, release assets, and
attestations.

#### Scenario: A visitor opens the repository contributor panel

- **WHEN** GitHub calculates contributors from the default branch
- **THEN** it lists `k1tvkli2003` as the sole OpenHUB contributor
- **AND** upstream contributors remain credited in the provenance section

#### Scenario: The default branch history is normalized

- **WHEN** the imported history is replaced with an owner-authored root commit
- **THEN** the old and new commit tree hashes are identical
- **AND** `v2.0.0`, its assets, checksum, SBOM, and attestation remain unchanged
