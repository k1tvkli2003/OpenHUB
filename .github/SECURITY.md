# Security policy

## Reporting a vulnerability

Do not disclose vulnerabilities in a public issue, discussion, or pull request.
Use [GitHub private vulnerability reporting](https://github.com/k1tvkli2003/OpenHUB/security/advisories/new)
and include the affected version, impact, minimal reproduction, and any useful
logs with secrets removed.

Reports are acknowledged on a best-effort basis within three business days.
Confirmed issues are coordinated privately until a fix and advisory are ready.

## Supported versions

| Version | Support |
| --- | --- |
| 2.x | Active |
| Earlier builds | Upgrade required |

## Scope

In scope:

- the Python control plane, OpenAI-compatible routes, account management, and
  dashboard backend under `app/`;
- the browser dashboard under `frontend/`;
- the native Windows client and pinned backend package;
- the official GitHub release artifacts published by this repository.

Out of scope:

- upstream OpenAI, Codex, Hermes, OpenCode, or third-party provider services;
- user-created configurations that deliberately expose a local-only route;
- packages or binaries distributed by another repository;
- secrets that a user has intentionally committed or published.

OpenHUB's shared account route is intended for numeric loopback hosts. Account
tokens and runtime stores must never be attached to a report; redact them before
submission.
