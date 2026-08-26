## ADDED Requirements

### Requirement: Cleanup requires an immutable preview

OpenHUB SHALL discover only allowlisted old archive, diagnostic-dump, and
temporary-file categories. Preview SHALL return exact paths, sizes, and a
snapshot digest. Apply SHALL require the same digest, recompute the complete
candidate set, and reject any mismatch before deleting a file.

#### Scenario: Previewed files changed

- **WHEN** the candidate set or any candidate's size or modification time
  changes after preview
- **THEN** apply is rejected and the operator must preview again

#### Scenario: Protected data is present

- **WHEN** native chat/task stores, credentials, projects, canonical skills or
  memories, fresh files, unrelated suffixes, or symbolic links are present
- **THEN** none of those paths appears in the cleanup candidate set
