<div class="openhub-hero" markdown>
  <img class="openhub-hero__mark" src="assets/brand/openhub-route-hub.png" alt="OpenHUB hex-lightning mark">

<h1 class="openhub-hero__title">
  <img src="assets/brand/openhub-wordmark.png" alt="OpenHUB">
</h1>

**One local control plane for Codex, Hermes Agent, OpenCode, and an OpenAI account pool.**

[Download the Windows release](https://github.com/k1tvkli2003/OpenHUB/releases/latest){ .md-button .md-button--primary }
[Read the source](https://github.com/k1tvkli2003/OpenHUB){ .md-button }
</div>

OpenHUB is a Windows-first, local-first desktop application. Its native Pulse
surface discovers supported coding-agent runtimes, reports task/model/token
activity, keeps child-agent usage attached to the root task, and invokes only
controls the owning runtime can actually perform. A bundled FastAPI sidecar also
provides account, routing, automation, usage, and optional web-dashboard APIs.

## What is in this repository

| Surface | Verified role |
| --- | --- |
| **Native Windows app** | Pulse for Codex, Hermes, and OpenCode; accounts; usage; runtime-aware actions; safe cleanup |
| **Local OpenAI router** | Stable loopback Responses and Chat Completions endpoints with per-request eligible-account failover |
| **Knowledge federation** | Live links/loaders to one canonical `~/.codex` skills, memory, and instruction store—no divergent copies |
| **Optional web dashboard** | Browser administration for the same backend; it is not a hosted cloud service |
| **Backend deployment** | Source, Docker, Compose, and Helm manifests for operators who provide/build their own image |

The provider-neutral base URL used by local clients is:

```text
http://127.0.0.1:2455/backend-api/openhub/v1
```

Start with [Getting Started](getting-started.md), then copy the relevant
[Client Setup](client-setup.md) example.

## Runtime behavior

OpenHUB keeps runtime-native chats and credentials in their original stores.
It normalizes observable task identity, parent/child lineage, activity, model,
and usage without rewriting transcripts. Pause, resume, stop, or open controls
are shown only when the corresponding Codex, Hermes, or OpenCode adapter has a
verified native primitive; unsupported actions stay visibly unsupported.

Transient stream/adapter gaps remain in reconnecting state for 20 seconds. On
recovery, durable state and token deltas are reconciled before the task returns
to active or idle. Admission and backoff are scoped to requests/accounts, so an
overloaded task does not turn every unrelated chat into a single global queue.

## Identity and sign-in boundary

The OpenHUB window, local callback, documentation, and releases use the
OpenHUB identity shown above. OpenAI hosts its own authorization page using the
official Codex OAuth client; that provider-hosted page may display Codex. This
repository does not claim a separately registered OpenHUB OAuth application.
OpenHUB never receives the password entered on OpenAI's page.

## Release boundaries

- Windows x64 is the verified native target for 2.0.0.
- Release archives are SHA-256 checked but not Authenticode-signed.
- No cloud-hosted OpenHUB service, public GHCR image, or OCI Helm chart is
  advertised by this release. Docker/Helm guides build locally or require an
  image location supplied by the operator.
- Runtime chats, provider credentials, `.openhub`, and the canonical `.codex`
  store are never release inputs.

OpenHUB is MIT-licensed. Its upstream provenance and contributor acknowledgements
are recorded in the
[README provenance and thanks](https://github.com/k1tvkli2003/OpenHUB#license-provenance-and-thanks).

---

*Specs: [public product identity](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/public-product-identity) · [multi-runtime control](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/multi-runtime-control) · [shared OpenAI router](https://github.com/k1tvkli2003/OpenHUB/tree/main/openspec/specs/shared-openai-router)*
