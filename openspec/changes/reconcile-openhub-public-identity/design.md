# Design

## Identity ownership boundary

OpenHUB owns its native/web UI, local callback page, documentation, packages,
repository metadata, and release artifacts. Those surfaces use the approved
hex-lightning image unchanged and may pair it with the generated OpenHUB
typographic wordmark. The wordmark is supplemental and is not repeated inside
dense operational screens.

OpenAI owns the hosted authorization surface. OpenHUB uses the public OAuth
client and redirect contract shipped for Codex compatibility, so the hosted
page may identify the official Codex client. The product discloses this before
opening the page and documents the boundary. It must never imply that a
third-party OAuth identity was registered for OpenHUB when none exists.

## Truthful public documentation

The Pages home is a product entry point, not a mirror of inherited screenshots.
It describes the Windows native control plane first and labels the optional
backend/web dashboard separately. Capability statements link to implementation,
tests, or owning OpenSpec contracts. Limits are explicit: Windows artifacts are
unsigned, no hosted cloud service is included, and no GHCR image or OCI chart is
advertised until its publish workflow and public package both exist.

## Backward-compatible key identity

New keys use `sk-openhub-` plus 32 bytes of URL-safe random material. Key
validation remains hash-based and therefore accepts every existing key. The
Codex usage identity discriminator recognizes both `sk-openhub-` and the legacy
`sk-clb-` prefix so old keys retain their special routing behavior. No database
rewrite is needed.

## Drift prevention

A source-level identity contract scans only active, publishable surfaces. It
allows archived specifications, git history, license/provenance acknowledgments,
and explicit compatibility literals. It rejects old product names in active UI,
the inherited terminal favicon, legacy screenshots referenced by Pages,
upstream registry install commands, and release metadata that disagrees with
OpenHUB.

Release verification is part of that boundary. Every external lint, test, and
build command must stop the job on a non-zero exit before packaging can start.
Native compatibility fixtures derive their expected backend version from the
same release-patched source constant as the client, so alpha, beta, RC, and
stable runs exercise the protocol contract instead of failing on a hard-coded
base version.
