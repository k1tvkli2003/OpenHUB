## Why

OpenHUB can manage accounts and routing, but it cannot show whether the Codex
tasks using this Windows profile are actively generating, reasoning, running a
tool, retrying, stalled, failed, or idle. Provider switching also has no shared
operational surface, so a user cannot see the active model/provider or confirm
that a switch completed without jumping between files, terminals, and Codex.

## What Changes

- Add a native Codex Pulse destination inside OpenHUB; do not create a second
  standalone application.
- Discover recent Codex tasks from the local Codex state database in read-only
  mode and enrich them from bounded rollout tails and the local Ox bridge.
- Show a semantic colored heartbeat, task phase, model, provider, context use,
  last activity, and token deltas since the Pulse session began.
- Show aggregate token usage for the last minute, last hour, and current Pulse
  session without persisting or exposing prompt content.
- Show local Ox admission pressure, including queued work, active slots, and the
  in-flight request-byte budget, so overload is visible before it becomes a
  retry storm.
- Open a selected task through its validated `codex://threads/<uuid>` deep link.
- Expose OpenAI/Ox mode through the existing safe provider switcher, retaining
  its confirmation, atomic config update, history repair, and relaunch behavior.
- Degrade explicitly when the state database, rollout, bridge, or switcher is
  unavailable instead of inventing healthy state.

## Non-goals

- No independent Windows widget or second installed executable.
- No writes to the Codex state database or rollout history.
- No display of hidden reasoning text, credentials, prompt bodies, or account
  identities.
- No replacement of OpenHUB account-routing telemetry.

## Capabilities

### New Capabilities

- `codex-task-observability`

### Modified Capabilities

None.

## Impact

- Affected code: native Windows navigation, a focused Pulse data service and
  model, the Pulse page, Windows deep-link bridge, tests, and packaging lockfile.
- Data safety: read-only access to `state_*.sqlite`, bounded read-only rollout
  tails, and loopback-only bridge health/metrics.
- Runtime: one cached refresh loop while the Pulse page is mounted; no polling
  while the destination is not visible. The local Ox adapter bounds concurrent
  inference and exact duplicate tool-output transfer without summarizing or
  dropping unique conversation context.
