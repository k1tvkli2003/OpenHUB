## ADDED Requirements

### Requirement: OpenAI Pool uses the live authoritative catalog

The built-in OpenAI Pool profile MUST obtain its Codex model catalog through the
managed local endpoint backed by current registered-account catalog refresh.
It MUST NOT pin a stale bundled OpenAI catalog. Authoritative GPT-5.6 entries
MUST retain their source metadata so the Codex client does not label them custom
solely because a stale local profile omitted them.

#### Scenario: A new GPT-5.6 catalog entry becomes available

- **WHEN** an eligible registered account refreshes an authoritative model
  catalog containing a new GPT-5.6 slug
- **THEN** the managed `/codex/models` response exposes that entry to Codex
- **AND** the OpenAI profile requires no file update or app restart
