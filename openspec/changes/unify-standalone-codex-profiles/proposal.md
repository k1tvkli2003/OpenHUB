## Why

OpenHUB currently treats account launch routing, provider switching, and task
telemetry as adjacent features rather than one coherent control plane. The
OpenAI managed route is pinned to a single prepared account, Ox depends on
machine-specific scripts, subagents inflate task counts, and there is no
Codex-native lifecycle control. This prevents safe standalone use and a
credible open-source release.

## What Changes

- Add a non-secret Codex profile registry with built-in OpenAI Pool and Ox
  profiles, import support, active-profile state, and portable paths.
- Supervise a loopback Codex app-server on Windows and launch the official
  desktop client against the selected profile with adoption verification.
- Guard profile changes with active root-task discovery, explicit confirmation,
  Codex shutdown, app-server replacement, rollback, and relaunch.
- Add root-task pause/resume and context compaction controls through app-server.
- Aggregate subagents under their `sessionId` root with exact token rollups.
- Let automatic managed OpenAI traffic fail over between registered accounts
  while preserving manual and file-continuity pins.
- Package the Ox bridge/catalog/runtime without personal paths.
- Keep every profile on one auto-discovered canonical Codex home and synchronize
  against the installed Desktop/CLI/app-server during first-run discovery.
- Add a selectable, dry-run-first Cleaning surface for old task groups and
  known OpenHUB temporary/cache files with archive/recovery safeguards.
- Add public documentation and a secure, reproducible Windows GitHub release.

## Non-goals

- Storing account credentials in profiles or source control.
- Copying rollout histories or project files between providers.
- Exposing the local app-server beyond loopback.
- Claiming a production support SLA for Codex's experimental WebSocket transport.
- Claiming Authenticode signing without a real certificate.

## Capabilities

### New Capabilities

- `codex-profile-management`
- `codex-task-lifecycle`
- `safe-cleaning`

### Modified Capabilities

- `codex-task-observability`
- `account-routing`
- `model-catalog-compat`
- `deployment-installation`
- `release-automation`
- `user-documentation`

## Impact

- Affected code: native Windows runtime/state/UI, Codex integration API,
  managed proxy routing, Ox bridge packaging, safe-cleaning inventory/journal,
  tests, docs, and workflows.
- Security: loopback-only app-server/proxy surfaces; profiles contain no secrets;
  publication is gated by secret and personal-path scans.
- Compatibility: unmanaged launch remains available when the installed Codex
  build lacks the required WebSocket connection capability.
