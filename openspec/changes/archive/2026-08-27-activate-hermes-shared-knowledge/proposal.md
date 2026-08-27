# Change: Activate Hermes shared knowledge during federation

## Why

OpenHUB installs its Hermes shared-knowledge plugin, but current Hermes releases
treat user plugins as opt-in. An installed-but-disabled plugin leaves canonical
Codex instructions and memory absent from Hermes prompts even though the
federation manifest reports success.

## What Changes

- Make an applied knowledge-federation operation enable the managed
  `openhub-shared-knowledge` Hermes plugin explicitly.
- Remove only that managed plugin from Hermes' disabled list while preserving
  all unrelated plugin choices.
- Add regression coverage for enabled/disabled-list preservation and a live
  Hermes activation probe.

## Impact

- Affected spec: `shared-knowledge-store`
- Affected code: `app/modules/knowledge_federation/service.py`
- Affected tests: `tests/unit/test_knowledge_federation.py`
- External state: the user's Hermes `config.yaml` is changed only when
  federation is applied, after its existing backup is created.
