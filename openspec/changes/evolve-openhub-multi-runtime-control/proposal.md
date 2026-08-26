# Change: Evolve OpenHUB into the OpenHUB multi-runtime control plane

## Why

Codex, Hermes, and OpenCode are independent agent runtimes, but they should not
drift into three copies of the user's skills, memories, and global agent
instructions. OpenHUB must observe and control all three runtimes while keeping
one canonical live knowledge repository and one provider-neutral local OpenAI
account router. The earlier dual-runtime/resource-copy proposal is superseded.

## What changes

- Complete the existing desktop product's identity as OpenHUB without creating
  a second app or unnecessarily redesigning the current UI.
- Treat Codex, Hermes, and OpenCode as first-class runtime adapters in one Pulse
  surface, with runtime-qualified task identity, lineage, usage, health, and
  capability-aware controls.
- Keep `C:/Users/K1/.codex` as the sole canonical repository for user-authored
  skills, durable memories, and global agent instructions. Hermes and OpenCode
  consume those files through live links/loaders; OpenHUB does not maintain
  divergent copies.
- Retain the encrypted OpenAI account pool and expose one stable, loopback-only,
  OpenAI-compatible endpoint usable by all three runtimes without restart when
  the selected account changes.
- Keep independent task traffic concurrent. Apply adaptive, scoped overload
  controls at account/request boundaries instead of a global single-request
  queue.
- Keep transient stream gaps in `reconnecting` for 20 seconds, reconcile
  durable task/usage deltas after recovery, and only then surface degradation.
- Preserve all native chat/session stores. No Codex, Hermes, or OpenCode chat,
  database, attachment, project, or credential migration is part of this
  change.
- Complete a release-brand cutover so every active product, package, service,
  repository, workflow, and release surface uses the OpenHUB identity. Preserve
  the existing logo asset unchanged.

## Impact

- Affected capabilities: shared knowledge federation, account routing,
  multi-runtime observability/control, stream recovery, Windows packaging and
  release identity.
- Affected code: FastAPI router/runtime APIs, runtime discovery adapters,
  Flutter controller/models/Pulse UI, and safe federation setup/verification.
- Data boundary: OpenHUB may replace only OpenHUB-owned generated resource-copy
  outputs after ownership and content verification. Native runtime resources
  and canonical Codex files remain untouched.
