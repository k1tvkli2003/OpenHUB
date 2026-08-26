## ADDED Requirements

### Requirement: Read-only cleaning inventory

OpenHUB SHALL make no cleaning mutation until it has produced a read-only
inventory of selectable root task groups and allowlisted generated-file
categories. The inventory MUST report age, counts, bytes, recovery method, and
protected exclusions without reading project-file contents.

#### Scenario: User opens Cleaning

- **WHEN** the user opens Settings > Cleaning
- **THEN** OpenHUB shows a metadata-only inventory and estimated reclaimable
  bytes while leaving every task and file unchanged

#### Scenario: Path is outside a managed cleaning root

- **WHEN** an item resolves outside the allowlisted OpenHUB temp, cache, log,
  or release-staging roots
- **THEN** it is excluded and cannot be selected by the cleaning plan

### Requirement: Root task trees are indivisible

Task cleanup SHALL operate on one `sessionId` root and all its descendants as a
single selection. The default task action MUST be recoverable app-server
archive, not rollout deletion.

#### Scenario: Old task owns subagents

- **WHEN** an old root task has one or more descendant agent threads
- **THEN** the preview shows one root selection with a descendant count and
  never presents those descendants as independent cleanup candidates

#### Scenario: User archives an old root

- **WHEN** the confirmed batch archives a selected root task tree
- **THEN** its stable task identity and history remain available for unarchive
  and the journal records the root id without titles or message contents

### Requirement: Exact selectable batch confirmation

Every mutation batch MUST contain exact selected action ids, source
fingerprints, exclusions, byte estimates, creation/expiry times, and a canonical
SHA-256. Mutation SHALL require confirmation of that exact unexpired hash.

#### Scenario: Inventory changed after preview

- **WHEN** a selected source changes, disappears, becomes active, crosses the
  allowlist boundary, or the plan expires
- **THEN** OpenHUB invalidates the batch, performs no mutation, and requires a
  fresh inventory and confirmation

#### Scenario: User changes a category or age selector

- **WHEN** the user edits any selector after preview
- **THEN** the prior hash is invalid and a new exact action list is generated

### Requirement: Recoverable generated-file cleanup

Eligible file cleanup SHALL be restricted to proven generated artifacts under
resolved managed roots. It MUST reject active/open files, databases, account or
credential stores, rollouts, workspaces, reparse points, and unknown files.
Material removal MUST use Windows Recycle Bin or a bounded OpenHUB quarantine
with a local journal.

#### Scenario: Temporary file is eligible

- **WHEN** a selected old file is under an allowlisted generated category,
  matches its current fingerprint, is not active, and has a recoverable target
- **THEN** OpenHUB moves it recoverably and verifies the journaled result

#### Scenario: Candidate is a rollout, database, secret, project, or reparse point

- **WHEN** scanning encounters protected or ambiguous data
- **THEN** OpenHUB excludes it even if it is old or large

### Requirement: Cleaning recovery and reporting

OpenHUB SHALL retain a local content-free action journal and provide recovery
for archived tasks and quarantined files while recovery evidence remains valid.
The result MUST separate applied, skipped, failed, and unverified actions.

#### Scenario: Batch partially fails

- **WHEN** one action fails verification
- **THEN** subsequent actions stop, completed actions remain journaled, safe
  rollback is offered, and the batch is not reported as fully complete

#### Scenario: User requests recovery

- **WHEN** the selected journal still proves unchanged recoverable destinations
- **THEN** OpenHUB previews the inverse actions and requires confirmation
  before unarchive or restore
