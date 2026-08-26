## MODIFIED Requirements

### Requirement: Account alias contract

The dashboard accounts API SHALL expose an operator-controlled, human-readable
`alias` on every account summary, and SHALL provide an endpoint that lets an
authenticated dashboard session set or clear that alias. The alias MUST be
persisted on the `Account` record and MUST be reflected in
`AccountSummary.alias`. When a non-empty alias is set, the same
`AccountSummary.display_name` field MUST resolve to the exact stored alias so
consumers preserve the operator's chosen label. When the alias is null or
cleared, `display_name` MUST be derived from the account email local part by
replacing separator runs with spaces, removing trailing decimal digits,
trimming whitespace, and uppercasing its first character. If derivation leaves
no characters, `display_name` MUST be `Account`. The stored email MUST remain
unchanged and available as secondary identity detail.

#### Scenario: Listing surfaces the alias when set

- **WHEN** the dashboard requests `GET /api/accounts` and at least one account has a stored alias
- **THEN** that account's summary includes `alias` with the stored value
- **AND** its `display_name` equals the alias exactly

#### Scenario: Listing falls back to email when alias is null

- **WHEN** an account has no alias and its email is `ali.reza_2024@example.com`
- **THEN** its `display_name` is `Ali reza`
- **AND** its `email` remains `ali.reza_2024@example.com`

#### Scenario: Numeric suffix removal can leave a single letter

- **WHEN** an account has no alias and its email is `m18247860@gmail.com`
- **THEN** its `display_name` is `M`

#### Scenario: Numeric-only local part uses a safe fallback

- **WHEN** an account has no alias and its email local part contains only digits
- **THEN** its `display_name` is `Account`

#### Scenario: Setting an alias persists and trims whitespace

- **WHEN** an authenticated dashboard session calls `PUT /api/accounts/{account_id}/alias` with `{"alias": "  Personal Plus  "}`
- **THEN** the response is 200 with `{"account_id": "...", "alias": "Personal Plus"}`
- **AND** subsequent `GET /api/accounts` reflects the trimmed value on both `alias` and `display_name`

#### Scenario: Empty or whitespace-only alias clears the value

- **WHEN** an authenticated dashboard session calls `PUT /api/accounts/{account_id}/alias` with `{"alias": ""}` or `{"alias": "   "}`
- **THEN** the response is 200 with `{"alias": null}`
- **AND** subsequent `GET /api/accounts` shows `alias: null` and a generated compact `display_name`

#### Scenario: Setting alias on an unknown account returns 404

- **WHEN** `PUT /api/accounts/{account_id}/alias` is called with an `account_id` that does not exist
- **THEN** the response is 404 with error code `account_not_found`

#### Scenario: Dashboard UI edits and searches aliases

- **WHEN** an operator opens the dashboard accounts page and selects an account
- **THEN** the account detail panel provides an `Account alias` control that can save a non-empty alias through `PUT /api/accounts/{account_id}/alias`
- **AND** clearing the control stores `alias: null` and restores the generated compact name
- **AND** account search matches the stored alias, generated display name, or email

### Requirement: Native account analytics use canonical account names

The native Windows API-key analytics surface SHALL resolve each current
account-cost row through the corresponding `AccountSummary.display_name` and
SHALL apply the same email-derived fallback for historical rows whose current
account summary is unavailable. It MUST NOT use a full email address as the
primary visible account label.

#### Scenario: Current account cost row uses its summary name

- **WHEN** an API-key cost row references a current account id
- **THEN** the visible label equals that account summary's `display_name`

#### Scenario: Historical account row derives a compact fallback

- **WHEN** a historical cost row has no current account summary but includes `keyvan23@example.com`
- **THEN** the visible label is `Keyvan`

### Requirement: Native Accounts page filters by subscription class

The native Windows Accounts page SHALL provide one composable subscription
filter with `All plans`, `Paid only`, and `Free only` choices. `Paid only` MUST
include accounts whose reported plan is Plus, Pro, Pro Lite, Team, Business,
Enterprise, or Edu. `Free only` MUST include plans classified by the existing
free-plan routing rule. Accounts with an unknown plan MUST remain visible under
`All plans` and MUST NOT be falsely classified as paid. The subscription filter
MUST combine with the existing search, state filter, and usage ordering without
changing the Next Route eligibility calculation.

#### Scenario: Operator shows only paid subscriptions

- **GIVEN** the account pool contains paid, free, and unknown plans
- **WHEN** the operator selects `Paid only`
- **THEN** only accounts with a reported paid subscription remain in the account list
- **AND** the current search, state filter, and remaining-usage order still apply

#### Scenario: Operator shows only free subscriptions

- **WHEN** the operator selects `Free only`
- **THEN** only accounts classified as free by the routing rule remain in the account list

#### Scenario: Subscription filter does not rewrite routing evidence

- **WHEN** the operator changes the subscription filter
- **THEN** Next Route continues to use the full pool of fresh eligible accounts
- **AND** no account subscription or routing setting is mutated
