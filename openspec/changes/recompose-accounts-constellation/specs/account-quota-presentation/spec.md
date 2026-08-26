## ADDED Requirements

### Requirement: Account state is scan-ready and source-aware

The Accounts screen MUST classify each visible account into Ready now, Needs
attention, or Offline or exhausted without hiding the account's remaining usage.
Every row MUST expose the canonical subscription, remaining usage, and a
symbolic freshness state derived from the existing usage sample timestamp and
the current OpenHUB app-session start time.

#### Scenario: App opens with cached account samples

- **GIVEN** an account has a cached usage sample older than the current app session
- **WHEN** the Accounts screen first renders
- **THEN** the row is marked as not refreshed since launch
- **AND** the cached remaining-usage value remains visible
- **AND** the state is not presented as a fresh upstream verification

#### Scenario: Refresh completes during the current session

- **GIVEN** an active account has remaining quota
- **WHEN** its usage sample timestamp is at or after the app-session start
- **THEN** the row is eligible for Ready now
- **AND** the row displays the sample age and exact timestamp through accessible detail

#### Scenario: Account cannot currently route

- **GIVEN** an account requires reauthentication, is paused or deactivated, or has exhausted quota
- **WHEN** the account list is rendered
- **THEN** the account is grouped outside Ready now
- **AND** its reason is represented by a distinct icon, label, and color rather than color alone

### Requirement: Next-route recommendations remain truthful

The Accounts screen MUST show at most three currently routable accounts in the
Next route rail. Every recommended account MUST have a successful quota sample
at or after the current OpenHUB app-session start. The rail MUST preserve the
active global remaining-usage order and MUST label the positions Best now,
Runner-up, and Fallback without claiming that a request was actually routed.

#### Scenario: Cached accounts have not refreshed this launch

- **GIVEN** active accounts have cached remaining-quota values from before the current app session
- **WHEN** the Next route rail renders before a successful refresh completes
- **THEN** those accounts are excluded from the rail
- **AND** the rail explains that no account has finished a successful refresh in this session

#### Scenario: Fewer than three accounts are routable

- **GIVEN** only one or two accounts are currently routable
- **WHEN** the Next route rail renders
- **THEN** only those accounts are shown
- **AND** no unavailable account is invented as a fallback

### Requirement: Manual account launch remains available

Every routable account row and the selected-account inspector MUST expose the
manual Open Codex action. The existing restart confirmation and managed-route
preparation semantics MUST remain unchanged.

#### Scenario: Codex is already running

- **GIVEN** the operator selects Open Codex for an account while Codex is running
- **WHEN** the existing launcher reports an already-running process
- **THEN** OpenHUB offers the existing explicit restart confirmation
- **AND** it does not replace Codex chats, settings, configuration, or auth files
