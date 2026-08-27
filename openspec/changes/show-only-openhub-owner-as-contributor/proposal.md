# Change: Show only the OpenHUB owner as a project contributor

## Why

GitHub currently derives OpenHUB's contributor panel from the imported
upstream commit graph, so it presents upstream contributors as direct OpenHUB
contributors. OpenHUB already preserves and thanks that work in its explicit
provenance section. The project-owned contributor registry and GitHub panel
should instead represent authorship of this repository itself.

## What changes

- Keep only `k1tvkli2003` in OpenHUB's project contributor registry.
- Normalize the default branch to one owner-authored root commit without
  changing any tracked file content.
- Preserve the stable and prerelease tags, release assets, attestations,
  license, and upstream provenance acknowledgments.
- Keep a local recovery ref for the pre-normalization branch tip and verify the
  old and new commit trees are byte-identical before publishing.

## Non-goals

- Rewriting, erasing, or claiming authorship of the upstream project's work.
- Removing upstream copyright, license, thanks, or provenance links.
- Moving or recreating the published `v2.0.0` release tag.
