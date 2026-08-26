<p align="center">
  <img src="native_windows/assets/brand/openhub-route-hub.png" width="150" alt="OpenHUB logo">
</p>

# OpenHUB

OpenHUB is a local, provider-neutral control plane for AI coding agents. It gives Codex, Hermes Agent, and OpenCode one Windows dashboard for live task health, model/token telemetry, task controls, shared knowledge, and resilient OpenAI account routing.

The application is local-first: account credentials remain encrypted in the local OpenHUB store, runtime-native chat databases remain owned by their original clients, and shared skills/memory are read live from one canonical workspace instead of copied into divergent trees.

## What it does

- **Pulse across runtimes** — shows active Codex, Hermes, and OpenCode tasks, their provider/model, heartbeat, context activity, and token usage since launch, in the last minute, and in the last hour.
- **Correct task lineage** — subagents are grouped under their root task and their usage rolls up into the parent instead of appearing as unrelated work.
- **Real runtime controls** — opens native sessions and exposes pause, resume, or stop only when the owning runtime can perform that action safely.
- **OpenAI account router** — exposes one loopback endpoint and selects an eligible account per request, allowing rate-limit failover without restarting the client.
- **Current model catalog** — serves live upstream metadata with a complete bundled GPT-5.6 fallback (`gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna`).
- **Shared knowledge federation** — treats `~/.codex` as the canonical live source for skills, memories, global instructions, MCP definitions, and task-history access used by federated clients.
- **Resilient streaming** — keeps connections alive, retries transient startup failures for at least 20 seconds, and recovers novel output after a reconnect without globally serializing unrelated tasks.
- **Safe cleanup** — previews exact allowlisted files and bytes, requires a second confirmation, then revalidates every candidate. Runtime chats, task stores, credentials, skills, and memories are never cleanup targets.
- **Account operations** — refreshes the complete account pool concurrently and supports explicit account deletion with an independent history choice.

## Architecture

```text
Codex ─────┐
Hermes ────┼── OpenHUB loopback router ── eligible OpenAI account pool
OpenCode ──┘             │
                         ├── Pulse + runtime controls
                         ├── usage / account / automation APIs
                         └── canonical ~/.codex knowledge federation
```

OpenHUB does not rewrite runtime-native transcript formats. Each client retains its own authoritative history, while OpenHUB exposes one logical control and observability layer over them.

## Install on Windows

1. Download `OpenHUB-Windows-2.0.0.zip` from the latest GitHub Release.
2. Extract the whole archive to a writable folder.
3. Run `Launch-OpenHUB.ps1` or `OpenHUB.exe`.
4. Open **Accounts** to connect OpenAI accounts, then use **Pulse** to inspect the detected runtimes.

The portable package contains the pinned backend sidecar; Python, `uv`, Git, and network package resolution are not required at launch. The first public build is checksum-verified but not Authenticode-signed, so Windows SmartScreen may request confirmation.

OpenHUB stores local state in:

```text
%USERPROFILE%\.openhub
```

Back up that directory to preserve encrypted account state and settings. Do not publish it or commit it to a repository.

## Shared OpenAI endpoint

The provider-neutral loopback base URL is:

```text
http://127.0.0.1:2455/backend-api/openhub/v1
```

Useful routes:

| Purpose | URL |
| --- | --- |
| Models | `http://127.0.0.1:2455/backend-api/openhub/v1/models` |
| Responses | `http://127.0.0.1:2455/backend-api/openhub/v1/responses` |
| Chat Completions | `http://127.0.0.1:2455/backend-api/openhub/v1/chat/completions` |
| ChatGPT-compatible base | `http://127.0.0.1:2455/backend-api/openhub` |

The shared route is deliberately loopback-only. OpenHUB owns account credentials and rotates accounts at request time; clients do not need to restart when the selected account changes.

### Hermes Agent

Point a Hermes custom provider at the shared URL and use either Responses or Chat Completions according to the model/provider adapter. Hermes remains the owner of its sessions and provider credentials; OpenHUB only owns credentials entered into OpenHUB.

### OpenCode

Configure an OpenAI-compatible provider with the same base URL. OpenHUB discovers the local OpenCode database for Pulse and opens a selected native session with the installed OpenCode CLI.

### Codex

Codex can use the ChatGPT-compatible base or the shared `/v1` base. The bundled catalog includes all required Rust-client metadata so GPT-5.6 entries remain first-class rather than falling back to a `custom` label.

More client examples live in [docs/client-setup.md](docs/client-setup.md).

## Shared skills, memory, and instructions

The canonical store is:

```text
%USERPROFILE%\.codex
```

OpenHUB's federation doctor verifies live links/configuration for Hermes and OpenCode. It does not maintain copied skill or memory repositories. Credentials stay in the store owned by their provider and are never written into generated MCP files, skills, logs, or transcripts.

### Safe cleanup

In **Settings → Safe storage cleanup**:

1. choose conversation archives, diagnostic dumps, and/or temporary files;
2. choose an age threshold;
3. preview the exact path list and total bytes;
4. confirm deletion of that exact snapshot.

If a file changes between preview and apply, cleanup is rejected or the file is skipped. Native chat and task databases are protected by design. Request-log and usage-history retention remain separately configurable in Advanced settings.

## Development

Requirements:

- Python 3.13 and [`uv`](https://docs.astral.sh/uv/)
- Flutter with Windows desktop support
- Visual Studio Build Tools with Desktop development for C++
- Bun for the optional web dashboard build

```powershell
uv sync --frozen
uv run pytest -q

Set-Location native_windows
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

Run the backend directly:

```powershell
uv run openhub
```

For FastAPI's development reloader, explicitly disable proxy-header projection:

```powershell
uv run fastapi run app/main.py --reload --no-proxy-headers
```

Build and run the container locally on a named bridge:

```bash
docker build -t openhub:local .
docker network inspect openhub-net >/dev/null 2>&1 || docker network create openhub-net
docker run -d --name openhub --network openhub-net -p 2455:2455 -p 1455:1455 openhub:local
```

Build the portable Windows package:

```powershell
./scripts/native_windows/Build-NativeWindowsPackage.ps1
```

## Verification

The repository gates releases on:

- Python lint and test suites;
- Flutter analysis, widget/unit tests, and Windows release compilation;
- strict OpenSpec validation;
- brand and secret scans;
- package manifest/hash verification;
- GitHub Actions YAML validation.

Release downloads include `SHA256SUMS.txt`; verify it before launching an artifact obtained outside GitHub Releases.

## Security and privacy

- Network-facing deployment is not the default. The shared multi-account route accepts numeric loopback hosts only.
- Tokens are encrypted at rest and are never returned by dashboard APIs.
- Do not upload `.openhub`, `.codex`, Hermes, or OpenCode runtime data.
- Report vulnerabilities privately through [GitHub Security Advisories](https://github.com/k1tvkli2003/OpenHUB/security/advisories/new).

### Project status

OpenHUB 2.0 is a Windows-first portable release. Linux/macOS backend deployment remains supported by the Python service, but the native operator UI and runtime-launch integration are currently verified on Windows x64. Production Windows code signing is not configured in this repository.

## License and provenance

OpenHUB is released under the [MIT License](LICENSE). It retains the original MIT copyright and builds on substantial work by the original upstream maintainers and contributors, with the OpenHUB multi-runtime control plane, Windows client, federation, and routing changes maintained here.
