## Context

The Codex profile already records task identity, model, provider, timestamps,
token totals, and rollout paths in `~/.codex/state_*.sqlite`. Rollout JSONL files
contain task lifecycle and token-count events. The local Ox adapter exposes
loopback health and, in version 3.3+, bounded active-request and usage metrics.
The existing provider switcher owns safe OpenAI/Ox transitions and history
repair. OpenHUB is therefore the correct host for a unified operator surface.

## Decisions

### One integrated Signal Ledger surface

Add `Pulse` as a native OpenHUB core destination. The page uses the existing
Signal Slate palette and shell, while its signature heartbeat maps directly to
task state: green active, cyan reasoning/tool activity, amber retry or stall,
red error, and muted gray idle. Symbols and text accompany every color.

### Read-only local telemetry boundary

Open the newest Codex `state_*.sqlite` database with SQLite read-only mode.
Query only recent, non-archived tasks. Never mutate Codex tables. Read rollout
files through bounded tails and cache unchanged file results by length and
modification timestamp, so idle tasks do not cause repeated large reads.

### Conservative lifecycle inference

`task_started` after the latest `task_complete` is active. Reasoning and tool
events refine the active phase. A completion with an error is failed; a normal
completion is idle. An unfinished task with no activity past the stall boundary
is shown as stalled, not silently idle. Ox `/metrics` may override the matching
task's phase with its exact retry/stream state. Unknown or unavailable sources
remain visibly degraded.

### Session-scoped token accounting

At Pulse service start, capture each task's current database token counter as a
baseline. Positive counter deltas become timestamped local samples. Aggregate
those samples for the last minute and hour, and current-minus-baseline for the
session total. Counter resets never become negative consumption.

### Quality-preserving local load control

The Ox adapter admits logical inference requests through a cancellation-aware
FIFO queue with both a concurrency ceiling and an aggregate serialized-byte
budget. Retryable overload or network failures reduce the active ceiling and
open a shared cooldown; sustained successful completions restore capacity one
slot at a time. A logical request retains one slot across its bounded retries
and stream recovery so retries cannot multiply the admitted load.

Large tool outputs may be compacted only when a later tool result is byte-for-
byte identical to an earlier result in the same request. The first full result
remains available and the duplicate is replaced with a content hash and the
earlier tool-call reference. Unique messages, user input, tool schemas, file
content, and compaction history are never semantically summarized by this
optimization. Because the upstream Chat Completions contract is stateless, the
adapter does not pretend that cross-turn delta-only context is safe.

Pulse surfaces queued requests, admitted slots, byte pressure, and cooldown
state from loopback metrics. Queue waits continue to emit transport keep-alives,
so ordinary local backpressure does not look like a disconnected stream.

### Existing switcher remains the only mutation path

OpenHUB does not edit `config.toml`, task rows, or histories. A provider change
launches the existing `Start-CodexMode.ps1`, which retains its mutex, user
confirmation, Codex shutdown/relaunch, atomic config update, state migration,
bridge validation, and history repair. Pulse only reports the result.

### Validated native task deep links

Extend the narrow Windows method channel with `openCodexThread`. Dart and C++
both accept only a canonical UUID and construct `codex://threads/<uuid>`
internally before `ShellExecuteW`, preventing arbitrary scheme execution.

## Preview-to-production manifest

| Layer | Type | Live responsibility | Verification |
| --- | --- | --- | --- |
| OpenHUB shell/navigation | live semantic UI | destination, keyboard/focus | widget + runtime |
| Main heartbeat | vector/custom paint | aggregate phase and animation | default + reduced motion |
| Token ledger | live semantic UI | minute/hour/session counters | deterministic service tests |
| Task rows | live semantic UI | model/provider/status/context/task link | long-title + narrow-width tests |
| Provider controls | live controls | call existing safe switcher | mocked process + live manual smoke |
| Status glyphs | Material/vector | redundant non-color state cue | semantics/widget tests |
| Concept preview | design-only raster | visual reference, never shipped as data | side-by-side review |

## Geometry and motion

- Base spacing unit: 4 px; primary rhythm: 8/12/16/24/32.
- Interactive controls: minimum 36 px in the dense Windows shell, with larger
  40 px primary controls where space permits.
- One surface shell and ruled rows; avoid nested card grids.
- Heartbeat animation uses repaint-only phase changes and pauses when reduced
  motion is enabled or the page is disposed.

## Risks and mitigations

- A live SQLite write may briefly contend with a read. Use read-only access,
  short queries, and retain the last valid snapshot with a degraded warning.
- Huge rollouts could be expensive. Read bounded tails and reuse cached parses.
- A request burst could overload the free Ox upstream. Bound admitted work by
  request count and bytes, remove cancelled queue entries, and recover capacity
  conservatively after successful completions.
- Context compaction could reduce answer quality. Deduplicate only exact large
  tool results while retaining the first full copy; never summarize unique
  conversation state automatically.
- A task started before Pulse may not include its start event in the tail. Use
  recent lifecycle evidence conservatively and label uncertain state as active
  or stalled only while the rollout is still changing.
- Provider switching closes Codex. Keep the switcher's existing confirmation;
  never pass `-SkipRunningCheck` from the UI.
