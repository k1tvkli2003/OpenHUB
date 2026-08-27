## MODIFIED Requirements

### Requirement: API Key creation

The system SHALL allow the admin to create API keys via `POST /api/api-keys`
with a `name` (required), `allowed_models` (optional list),
`weekly_token_limit` (optional integer), `expires_at` (optional ISO 8601
datetime), `assigned_account_ids` (optional list), and `usage_sections`
(optional comma-separated string, defaults to
`"upstream_limits,account_pool_usage"`). The system MUST generate new keys as
`sk-openhub-{32 bytes of URL-safe random material}`, store only the `sha256`
hash in the database, and return the plain key exactly once in the creation
response. Existing `sk-clb-` keys MUST remain valid without migration. The
system MUST accept timezone-aware ISO 8601 datetimes for `expiresAt`, normalize
them to UTC naive for persistence, and return the expiration as UTC in API
responses.

When `assigned_account_ids` is omitted or empty, the created key SHALL remain
unscoped and apply to all accounts. When it contains valid account IDs, the
created key SHALL enable account-assignment scope and persist those assignments.

#### Scenario: Create unscoped key without assigned accounts

- **WHEN** admin submits `POST /api/api-keys` without `assignedAccountIds`
- **THEN** the created key returns `accountAssignmentScopeEnabled = false`
- **AND** `assignedAccountIds = []`

#### Scenario: Create scoped key with assigned accounts

- **WHEN** admin submits `POST /api/api-keys` with valid assigned account IDs
- **THEN** the created key returns `accountAssignmentScopeEnabled = true`
- **AND** `assignedAccountIds` matches the supplied accounts

#### Scenario: Reject unknown assigned account IDs on create

- **WHEN** admin submits an unknown account ID in `assignedAccountIds`
- **THEN** the system returns 400

#### Scenario: Create key and show plain key

- **WHEN** admin submits a valid create payload
- **THEN** the response contains an `sk-openhub-` plain key exactly once
- **AND** subsequent reads never return the plain key

#### Scenario: Create key with timezone-aware expiration

- **WHEN** admin submits `{ "name": "dev-key", "expiresAt": "2025-12-31T00:00:00Z" }`
- **THEN** persistence succeeds without datetime binding errors
- **AND** the response represents the same UTC instant

#### Scenario: Legacy key continues to authenticate

- **WHEN** a stored active key was originally issued with `sk-clb-`
- **THEN** it authenticates through the same hash-based validation path
- **AND** no data rewrite or regeneration is required
