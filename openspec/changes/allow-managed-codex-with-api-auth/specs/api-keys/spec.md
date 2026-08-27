# api-keys delta

## ADDED Requirements

### Requirement: Trusted managed Codex route coexists with API-key authentication

When `api_key_auth_enabled` is true, the proxy API-key guard MUST allow the dedicated
managed Codex route to proceed without interpreting the Codex desktop bearer as a
OpenHUB API key, but only when the managed-route middleware activated the route from
a numeric raw-loopback socket peer. The exception MUST return no API-key policy and
MUST NOT apply to canonical `/v1/*`, canonical `/backend-api/codex/*`, or an attempted
managed-path request from any non-loopback or non-numeric peer.

#### Scenario: Trusted managed desktop request remains usable

- **GIVEN** `api_key_auth_enabled` is true
- **AND** the managed-route middleware receives a dedicated managed-path request from a numeric raw-loopback peer
- **WHEN** Codex supplies its own ChatGPT or OpenAI session bearer
- **THEN** the proxy API-key guard returns no OpenHUB API-key policy
- **AND** the prepared managed account route remains responsible for routing

#### Scenario: Remote managed-path attempt receives no exception

- **GIVEN** `api_key_auth_enabled` is true
- **AND** a non-loopback or non-numeric peer requests the dedicated managed path
- **WHEN** the request omits a valid OpenHUB API key
- **THEN** the proxy API-key guard rejects the request
