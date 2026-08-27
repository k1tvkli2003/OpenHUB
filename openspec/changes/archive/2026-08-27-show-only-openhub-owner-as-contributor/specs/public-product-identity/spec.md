## ADDED Requirements

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
