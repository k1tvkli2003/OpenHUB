## 1. Contracts and migration

- [ ] 1.1 Add typed non-secret profile registry, built-in OpenAI Pool/Ox
      profiles, validation, atomic persistence, and legacy import.
- [ ] 1.2 Add backend/profile APIs and redact machine/credential details.
- [ ] 1.3 Move Ox adapter/catalog into portable repository-owned assets.
- [ ] 1.4 Discover installed Codex Desktop, CLI, and canonical Codex home on
      first run; reject profile-specific home overrides and mismatched roots.

## 2. Managed runtime and routing

- [ ] 2.1 Add loopback app-server supervisor, capability/health probes, JSON-RPC
      client, crash recovery, and stale-state rejection.
- [ ] 2.2 Add live-root preflight, confirmation contract, transactional profile
      switch, rollback, Codex close/relaunch, and adoption verification.
- [ ] 2.3 Change automatic managed OpenAI selection from a hard pin to a
      failover-capable soft preference while preserving continuity hard pins.
- [ ] 2.4 Serve the current OpenAI model catalog through the managed profile and
      verify GPT-5.6 catalog metadata is not labeled custom when authoritative.

## 3. Task hierarchy and lifecycle

- [ ] 3.1 Group app-server threads by `sessionId`, retain parent hierarchy, and
      aggregate unique child token usage exactly once.
- [ ] 3.2 Implement root pause, interrupt, resume/continue, and target-window
      compaction preflight with partial-failure reporting.
- [ ] 3.3 Preserve bounded SQLite/rollout telemetry as a degraded fallback.

## 4. Native interface

- [x] 4.1 Produce and record responsive profile/task-control preview approval.
- [ ] 4.2 Implement the approved profile drawer, live-task switch guard, status,
      account-pool summary, and profile health.
- [ ] 4.3 Implement root-task disclosure and semantic Pause/Resume/Continue
      controls with keyboard, focus, reduced-motion, and narrow layouts.
- [ ] 4.4 Add a compact Settings > Cleaning surface with category/age
      selectors, exact dry-run preview, batch confirmation, progress, recovery,
      and journal history without redesigning the existing shell.

## 5. Safe cleaning

- [ ] 5.1 Add read-only inventory for root task groups and allowlisted
      OpenHUB temporary/cache/log/staging roots, including counts and bytes.
- [ ] 5.2 Add expiring canonical batch plans, SHA-256-bound confirmation,
      changed-source invalidation, exclusions, and audit journals.
- [ ] 5.3 Archive/unarchive selected root task trees and move eligible generated
      files through Recycle Bin or bounded quarantine; never independently
      clean a subagent or touch history/database/project/credential files.
- [ ] 5.4 Add cleaning unit/widget/runtime tests including stale-plan,
      reparse-point, active-file, collision, rollback, and recovery cases.

## 6. Standalone documentation and release

- [ ] 6.1 Replace machine-specific setup with portable discovery and package
      required Ox/runtime assets.
- [ ] 6.2 Write a concise README plus install, profiles, task control, cleaning,
      architecture, security, troubleshooting, and contribution docs linked to
      their owning OpenSpec capabilities.
- [ ] 6.3 Add least-privilege, SHA-pinned GitHub Actions for validation and a
      deterministic Windows `v0.1.0` release with hashes and SBOM.
- [ ] 6.4 Run source/package secret and personal-path scans, full tests, build,
      installer/runtime smoke, and rollback/failover/lifecycle probes.
- [ ] 6.5 Create the public `OpenHUB` repository, push only intended history,
      observe green Actions, publish release assets, and verify public links.
