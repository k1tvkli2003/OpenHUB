> **Superseded.** Do not continue this checklist. Continue at
> `openspec/changes/evolve-openhub-multi-runtime-control/tasks.md`.

## 1. Contracts and resource copy

- [x] 1.1 Cancel the full chat-migration scope and freeze the dual-runtime
      OpenHUB contract.
- [x] 1.2 Inventory Codex knowledge resources and define cache/build excludes.
- [x] 1.3 Back up Hermes knowledge state, copy resources, and verify hashes plus
      Hermes discovery without importing secrets or MCP settings.

## 2. Shared account router

- [ ] 2.1 Separate the stable OpenAI-compatible endpoint contract from Codex
      launch/profile state.
- [ ] 2.2 Publish client-specific connection guidance/status for Codex and
      Hermes without writing either client's credential store.
- [ ] 2.3 Verify parallel account selection, rate-limit/auth failover, sticky
      continuation isolation and bounded overload behavior.

## 3. Dual-runtime Pulse

- [ ] 3.1 Add normalized task, lineage, usage, health and capability schemas.
- [ ] 3.2 Implement read/control adapters for Codex and Hermes.
- [ ] 3.3 Roll child usage into roots while retaining child inspection.
- [ ] 3.4 Implement 20-second reconnect grace and durable gap reconciliation.
- [ ] 3.5 Replace provider switching in Pulse with per-runtime task controls.

## 4. Product and verification

- [ ] 4.1 Rename user-facing OpenHUB identity to OpenHUB with minimal UI
      disruption.
- [ ] 4.2 Run focused backend/Flutter tests, lint/type checks, build/install and
      live endpoint/runtime smoke checks.
- [ ] 4.3 Verify no Codex chat/database/project data changed and no secret was
      copied or logged.
