## 1. Contracts and preservation

- [x] 1.1 Supersede the dual-runtime/resource-copy proposal and freeze the
      Codex/Hermes/OpenCode contract.
- [x] 1.2 Inventory the installed OpenCode runtime, storage, APIs, controls, and
      supported knowledge-extension mechanisms.
- [x] 1.3 Verify the cancelled migration boundary: no native chat, session DB,
      attachment, project, or credential source is moved or copied.

## 2. Canonical knowledge federation

- [x] 2.1 Replace OpenHUB-owned Hermes copy outputs with manifest-verified live
      links/loaders to `C:/Users/K1/.codex` while preserving conflicts.
- [x] 2.2 Configure equivalent live access for OpenCode without replacing its
      native resource directories.
- [x] 2.3 Prove edits become visible from all three runtimes without sync/copy,
      and verify no credential-bearing paths are exposed.

## 3. Shared account router

- [x] 3.1 Publish one provider-neutral numeric-loopback endpoint contract for
      Codex, Hermes, and OpenCode.
- [x] 3.2 Verify rate-limit/auth failover, sticky continuation isolation, and
      account rotation without client restart.
- [x] 3.3 Prove independent task concurrency and adaptive overload behavior
      without a global single-request queue.

## 4. Multi-runtime Pulse

- [x] 4.1 Implement normalized discovery, lineage, usage, health, and capability
      adapters for Codex, Hermes, and OpenCode.
- [x] 4.2 Roll child/subagent usage into root tasks while retaining lineage.
- [x] 4.3 Wire only real task controls and explicit unsupported results.
- [x] 4.4 Implement 20-second reconnect grace and durable usage/state backfill.

## 5. Product and verification

- [x] 5.1 Complete the OpenHUB identity with minimal visual disruption, preserve
      the existing logo unchanged, replace provider switching with runtime
      status/control, and remove legacy product/package/service/repository names
      from active product, documentation, and release surfaces.
- [ ] 5.2 Run focused backend/Flutter tests, lint/type checks, concurrency and
      stream-recovery tests, build/install, and live runtime smoke checks.
- [ ] 5.3 Verify no native chat/project/credential data changed, no divergent
      knowledge copies remain, and account refresh/delete still work.
- [ ] 5.4 Finish standalone README, operational docs, safe cleanup controls,
      GitHub Actions, repository naming, and release artifacts after runtime
      acceptance passes.
