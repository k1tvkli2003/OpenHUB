> **Superseded on 2026-08-26.** The user requires Codex, Hermes, and OpenCode
> to consume one live canonical knowledge repository instead of copied trees.
> The active source of truth is
> `openspec/changes/evolve-openhub-multi-runtime-control/`.

# Change: Evolve OpenHUB into the OpenHUB dual-runtime control plane

## Why

The local account router is useful beyond one agent client. Codex and Hermes
must be able to use the same OpenAI-compatible loopback endpoint while OpenHUB
observes and controls tasks from both runtimes. The previous full chat-migration
proposal is explicitly cancelled; Codex conversations and databases remain in
place.

## What changes

- Rename the user-facing desktop product from OpenHUB to OpenHUB without
  creating a second app.
- Retain the encrypted OpenAI account pool and expose one stable, loopback-only,
  OpenAI-compatible endpoint for both Codex and Hermes.
- Remove provider-profile switching from OpenHUB. Provider/model selection stays
  owned by each agent runtime.
- Add runtime adapters that discover Codex and Hermes tasks, normalize lineage,
  health, activity, model/provider and usage, and expose real pause/resume/open
  actions where the runtime supports them.
- Keep transient stream disconnects in a reconnecting state for 20 seconds and
  reconcile durable task/usage state after recovery before showing an error.
- Copy only Codex global instructions, durable memories, and executable skill
  sources into Hermes. Do not copy chats, project files, credentials, MCP
  credentials, dependency caches, virtual environments, or build output.

## Impact

- Affected capabilities: account routing, proxy runtime observability, frontend
  architecture, runtime integration, resource portability.
- Affected code: FastAPI dashboard APIs, proxy routing/retry paths, Flutter
  controller/models/Pulse UI, Windows runtime discovery, and a selective Hermes
  resource synchronizer.
- Destructive boundary: none. This change copies knowledge resources and leaves
  every Codex source intact.
