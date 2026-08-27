# Changelog

All notable OpenHUB releases are documented here.

## 2.0.0 — 2026-08-26

Initial public OpenHUB release.

### Added

- Native Windows Pulse for Codex, Hermes, and OpenCode task health, model,
  provider, lineage, controls, and rolling token usage.
- Provider-neutral loopback OpenAI endpoint with per-request account routing.
- Live shared-knowledge federation rooted at the canonical `~/.codex` store.
- Safe preview-and-confirm cleanup for allowlisted old archives, diagnostics,
  and temporary files.
- Complete GPT-5.6 fallback catalog for Sol, Terra, and Luna.
- Account-pool refresh and explicit account deletion with an independent
  history choice.

### Changed

- Replaced global single-flight overload behavior with bounded, adaptive,
  account-scoped concurrency.
- Hardened Ox startup and streaming with a 20-second reconnect grace,
  keepalives, bounded retries, and durable output/usage reconciliation.
- Consolidated the product, package, executable, service, data-directory,
  documentation, workflow, and repository identity under OpenHUB while
  preserving the original logo bytes.

### Release artifacts

- Self-contained Windows x64 ZIP with pinned backend.
- SHA-256 checksums.
- SPDX JSON software bill of materials.
- GitHub artifact provenance attestation.

The project retains upstream MIT attribution and history. Earlier implementation
history remains available in Git rather than being relabelled as OpenHUB
releases.
