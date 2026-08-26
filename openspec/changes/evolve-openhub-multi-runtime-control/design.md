# Design

## Runtime ownership

OpenHUB is a provider-neutral control plane. Codex, Hermes, and OpenCode retain
their native sessions, authentication, provider catalogs, model selection, and
process lifecycle. Each adapter publishes a normalized contract but advertises
only actions it can execute through a verified native primitive. OpenHUB never
simulates pause, resume, stop, or open success.

## One live knowledge repository

`C:/Users/K1/.codex` is the canonical source for personal skills, memories, and
global `AGENTS.md` instructions. Runtime-owned credential stores, provider
configuration, native session databases, dependency caches, and generated
artifacts remain outside this federation.

Hermes and OpenCode receive stable, runtime-specific loader/link entry points
that resolve directly to the canonical paths. The setup is idempotent and
records link targets plus ownership in a manifest. It never materializes a
second content tree. Existing native runtime resources are preserved alongside
the shared entry point.

The previous Hermes copy output is an OpenHUB-owned transitional artifact. It
may be removed only after its manifest proves ownership, every target resolves
inside the expected Hermes import roots, and any changed/conflicting file is
preserved. A timestamped backup remains available.

## Provider-neutral OpenAI endpoint

The encrypted OpenHUB account database remains the credential owner. A stable
numeric-loopback OpenAI-compatible base URL serves Codex, Hermes, and OpenCode.
Account eligibility and cooldown are evaluated per request. Each account is
attempted at most once per routing round. Provider-owned continuation affinity
is scoped to its conversation and never serializes unrelated work.

Admission uses high, bounded concurrency with per-account stream/request limits
and adaptive backoff under measured overload. It does not introduce a global
single-flight gate across tasks or runtimes.

## Unified Pulse

Adapters emit runtime id, native id, root/parent ids, title, cwd, provider,
model, lifecycle, activity timestamps, cumulative token counters, and action
capabilities. Runtime-qualified ids prevent collisions. Child/subagent usage is
rolled into the root task while lineage remains inspectable.

Rolling one-minute, one-hour, and app-lifetime usage is calculated from
monotonic cumulative samples. On adapter or stream loss, OpenHUB retains the
last verified row and marks it reconnecting for 20 seconds. Recovery rereads
durable sequence/token state and emits the missing delta before returning to
active or idle. Only grace expiry or a verified terminal event becomes an
error.

## Out of scope

- Migrating, copying, rewriting, or deleting native chats, session databases,
  attachments, or project worktrees.
- Copying provider credentials, auth databases, MCP secrets, or browser tokens.
- Forcing all runtimes to expose identical controls when native capabilities
  differ.
- Reintroducing the removed Ox/provider-profile switcher.

## Brand cutover

The accepted logo pixels/assets remain unchanged. Active source metadata,
window/product strings, executable/package/service/shortcut names, settings
paths introduced by this project, README/docs, repository/workflow/release
metadata, and generated artifacts use OpenHUB. Historical archived specs may
retain old names only when rewriting them would destroy provenance; they are not
shipped as active branding.
