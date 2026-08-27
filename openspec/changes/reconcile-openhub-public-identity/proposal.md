# Change: Reconcile OpenHUB public identity and release truth

## Why

OpenHUB's native product has already adopted its final name and approved
hex-lightning mark, but several public surfaces still inherit screenshots,
icons, key prefixes, and install examples from the upstream project. GitHub
Pages therefore describes a different product, and the OAuth hand-off does not
clearly separate OpenHUB-controlled UI from OpenAI's provider-hosted Codex
identity. A public release must not ship that ambiguity.

## What changes

- Publish a Pages home and navigation that describe only capabilities that are
  present and verified in this repository, using the approved OpenHUB mark and
  a companion OpenHUB wordmark.
- Remove legacy branded screenshots and unsupported registry/chart claims from
  active documentation.
- Brand the local OAuth completion surface as OpenHUB and disclose before sign
  in that OpenAI hosts the authorization page under its official Codex OAuth
  client identity; OpenHUB does not claim an independently registered OpenAI
  OAuth application.
- Generate new downstream API keys with an `sk-openhub-` prefix while continuing
  to authenticate existing `sk-clb-` keys without migration or invalidation.
- Rename OpenHUB-owned shortcuts and browser icons, while retaining historical
  license/provenance records and explicitly thanking the upstream Codex LB
  project and contributors.
- Add fail-fast, release-version-invariant gates that reject stale public
  branding, fake screenshots, unpublished artifact locations, mismatched
  release metadata, and any failed verification command before packaging.

## Non-goals

- Rebranding or imitating OpenAI's provider-hosted authorization page.
- Rewriting git history, archived OpenSpec provenance, or third-party copyright
  notices.
- Claiming a container image, OCI Helm chart, code signature, or hosted service
  that this repository does not publish.

## Impact

- Affected capabilities: public product identity, user documentation, API keys,
  OAuth hand-off disclosure, Windows packaging, and release automation.
- Affected code: MkDocs assets/pages, OAuth completion template, native/web
  account dialogs, API-key generation/recognition, installer shortcut naming,
  public metadata, tests, and release packaging.
- Compatibility: existing keys and data remain valid; old exact shortcut names
  may be removed only as a bounded compatibility cleanup during install.
