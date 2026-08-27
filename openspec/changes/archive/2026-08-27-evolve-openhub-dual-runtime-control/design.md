# Design

## Runtime ownership

OpenHUB is a control plane, not an agent runtime. Codex and Hermes retain their
own provider catalogs, authentication, sessions and model selection. OpenHUB
uses two adapters behind one normalized task API. Unsupported actions are
reported as capabilities instead of being simulated.

## Shared OpenAI endpoint

The existing account database remains the credential owner. The public client
contract is a stable numeric-loopback base URL with OpenAI-compatible model,
Responses and Chat Completions routes. A request samples eligible accounts
without a global single-request gate. Sticky continuation state pins only the
conversation that cannot be replayed safely; independent tasks continue in
parallel.

Retry classification separates transport interruption, retryable capacity/rate
limits, authentication failure, and terminal request errors. Each eligible
account is attempted at most once per routing round. The endpoint never asks
Codex or Hermes to restart when it rotates accounts.

## Unified Pulse

Each adapter emits runtime id, root task id, optional parent id, title, cwd,
provider, model, lifecycle state, last activity, cumulative input/output/cache
tokens, and action capabilities. Child usage rolls up to the root while child
rows remain inspectable. Deduplication keys include runtime id so unrelated
Codex and Hermes task ids cannot collide.

The UI polls durable snapshots and may augment them with live stream/process
signals. A disconnect starts a 20-second reconnect grace period. During grace
the task is `reconnecting`, not failed. Recovery reads durable sequence/token
state and backfills missed deltas before returning to active/idle. Only an
expired grace window or explicit terminal event becomes an error.

## Resource copy

The synchronizer inventories source and destination by relative path, size and
SHA-256. It merges AGENTS.md and durable memory summaries into Hermes memory,
and copies each user skill under `skills/codex-imports/<name>`. It includes
SKILL.md, scripts, references, examples, templates and intentional assets while
excluding `.git`, `node_modules`, virtual environments, caches, bytecode,
coverage, package/build output, logs and temporary files. Destination conflicts
are skipped unless byte-identical; no overwrite is implicit. A timestamped
backup and manifest make the operation reversible.

## Out of scope

- Codex chat/session/database migration or deletion.
- Copying project worktrees or attachments.
- Importing provider credentials or secret-bearing MCP configuration.
- A separate provider-profile switcher inside OpenHUB.
