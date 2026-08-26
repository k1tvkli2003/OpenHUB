# Allow trusted managed Codex launches with API authentication

## Why

OpenHUB exposes two local traffic contracts that must coexist: API-key-authenticated
OpenAI-compatible `/v1` access, and a dedicated process-scoped managed Codex route.
Enabling global API-key authentication currently makes the managed route interpret the
Codex desktop session bearer as a OpenHUB API key, breaking an otherwise trusted
loopback launch.

## What changes

- Treat only the dedicated managed route activated by the numeric raw-loopback
  middleware as an internal trusted caller.
- Keep normal `/v1/*` and `/backend-api/codex/*` routes API-key protected when the
  global switch is enabled.
- Add regression coverage proving that a remote peer cannot activate the exception.

## Affected capability

- `api-keys`
