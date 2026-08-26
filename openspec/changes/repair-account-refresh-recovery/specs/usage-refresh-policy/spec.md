## MODIFIED Requirements

### Requirement: Usage refresh deactivates on clear deactivation signals

The system MUST deactivate accounts only when usage refresh receives a clear
permanent account deactivation signal. A bare HTTP `404` without a permanent
error code or explicit deactivation message MUST be treated as a retryable
refresh failure and MUST NOT make an otherwise routable account permanently
unavailable.

Credential/session invalidation codes such as `token_invalidated`,
`token_expired`, and `app_session_terminated` MUST remain
`reauth_required` rather than `deactivated`.

#### Scenario: Generic usage 404 stays retryable

- **GIVEN** an account that is otherwise eligible for routing
- **WHEN** its usage request returns HTTP `404` with a generic fetch-failed
  message and no permanent error code
- **THEN** usage refresh records no permanent account-state downgrade
- **AND** a later bounded refresh may retry the account

### Requirement: Legacy generic-404 deactivations recover from fresh evidence

Refresh MUST retry a row whose status is `deactivated` only when its persisted
reason exactly matches the legacy generic usage-404 failure produced by this
application. The retry MUST bypass cached usage freshness. A successful fresh
fetch MUST clear that exact legacy reason with a compare-and-set and MUST derive
the replacement status from the fresh primary and long-window quota evidence.
Other deactivated reasons and `reauth_required` rows MUST remain skipped.

#### Scenario: Healthy legacy row returns to the routing pool

- **GIVEN** an account deactivated with the exact legacy generic-404 reason
- **AND** fresh upstream usage shows available primary and long-window quota
- **WHEN** usage refresh runs
- **THEN** a fresh usage sample is stored
- **AND** the account atomically becomes `active`
- **AND** its deactivation reason, reset, and blocked markers are cleared

#### Scenario: Legacy row recovers to a quota-limited status

- **GIVEN** an account deactivated with the exact legacy generic-404 reason
- **WHEN** fresh upstream usage shows an exhausted primary or long window
- **THEN** the account atomically becomes the matching `rate_limited` or
  `quota_exceeded` status
- **AND** the relevant fresh reset deadline is retained

#### Scenario: Real deactivation remains fail-closed

- **GIVEN** an account deactivated for any other reason
- **WHEN** background or manual usage refresh runs
- **THEN** the account is not retried or reactivated automatically
