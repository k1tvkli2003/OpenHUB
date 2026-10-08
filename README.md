# OpenHUB

OpenHUB is a local-first, provider-neutral control plane for AI coding agents. It gives Codex, Hermes Agent, and OpenCode a single Windows dashboard for live task health, model and token telemetry, task controls, shared knowledge, and resilient OpenAI account routing.

Credentials stay encrypted in the local OpenHUB store. Each runtime keeps its own native chat database and transcript format; OpenHUB reads them live instead of copying them into divergent trees. Shared skills and memory are federated from one canonical workspace (`~/.codex`).

## What's inside

- **Pulse across runtimes** — active Codex, Hermes, and OpenCode tasks with provider and model, heartbeat, context activity, and token usage since launch, in the last minute, and in the last hour.
- **Correct task lineage** — subagents group under their root task and their usage rolls up into the parent.
- **Real runtime controls** — native sessions open on demand; pause, resume, and stop are exposed only when the owning runtime can perform the action safely.
- **OpenAI account router** — one loopback endpoint (`http://127.0.0.1:2455/backend-api/openhub/v1`) selects an eligible account per request, so rate-limit failover works without restarting the client.
- **Current model catalog** — live upstream metadata with a bundled GPT-5.6 fallback (`gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-5.6-luna`).
- **Shared knowledge federation** — skills, memories, global instructions, MCP definitions, and task-history access served live from the canonical source.
- **Recovering runtime telemetry** — last verified state is preserved through a 20-second reconnect grace period, then durable task and usage deltas reconcile without globally serializing unrelated work.
- **Safe cleanup** — previews exact allowlisted files and bytes, requires a second confirmation, then revalidates every candidate. Runtime chats, task stores, credentials, skills, and memories are never cleanup targets.
- **Account operations** — concurrent refresh of the full account pool, plus explicit account deletion with an independent history choice.

## Architecture

```text
Codex ─────┐
Hermes ────┼── OpenHUB loopback router ── eligible OpenAI account pool
OpenCode ──┘             │
                         ├── Pulse + runtime controls
                         ├── usage / account / automation APIs
                         └── canonical ~/.codex knowledge federation
```

Backend is Python (FastAPI) under `app/` (`core`, `db`, `modules`, middleware, rate limiter, resilience). Frontend is a Vite + TypeScript dashboard under `frontend/`. Docs are MkDocs under `docs/`. Packaging covers a portable Windows build (`native_windows/`, `Launch-OpenHUB.ps1`) and Docker (`Dockerfile`, `Dockerfile.distroless`, compose files).

## Tech stack

Python 3.13, FastAPI, React + Vite + TypeScript frontend, local encrypted credential store, Docker, MkDocs, pytest/ruff/pre-commit, GitHub Actions.

## Getting started

1. Download `OpenHUB-Windows-2.0.0.zip` from the latest GitHub Release.
2. Extract the full archive to a writable folder.
3. Run `Launch-OpenHUB.ps1` or `OpenHUB.exe`.
4. Open **Accounts** to connect OpenAI accounts, then use **Pulse** to inspect detected runtimes.

The portable package embeds the pinned backend sidecar; Python, `uv`, Git, and network package resolution are not needed at launch. The first public build is checksum-verified but not Authenticode-signed, so Windows SmartScreen may ask for confirmation. Local state lives in `%USERPROFILE%\.openhub` — back it up, never commit it. See `docs/getting-started.md` and `.env.example` for configuration.

## Status

Active development. Version 2.0.0, classified Alpha. Backend, dashboard, router, docs, and release pipeline are all present in the tree.
