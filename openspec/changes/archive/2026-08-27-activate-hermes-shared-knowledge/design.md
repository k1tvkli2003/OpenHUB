# Design

## Decision

Treat activation as part of the existing explicit `apply=True` federation
transaction. The managed plugin is useless when merely installed, and the
federation contract promises live prompt access rather than file presence.

Hermes stores opt-in state under `plugins.enabled` and an overriding deny-list
under `plugins.disabled`. OpenHUB will append its own plugin id to the enabled
list and remove only that same id from the disabled list. Existing list order
and unrelated entries remain untouched.

## Safety

- The existing pre-mutation Hermes configuration backup remains the rollback
  source.
- Invalid plugin configuration types fail closed before rewriting the file.
- OpenHUB never enables, disables, or deletes any unrelated plugin.
- Dry-run mode remains read-only.

## Verification

1. Unit tests prove preservation of unrelated enabled and disabled entries.
2. Strict OpenSpec validation passes.
3. Applying federation to the real Hermes home creates a new backup and makes
   `hermes plugins list --plain --no-bundled` report the plugin as enabled.
4. A fresh-process prompt-build probe proves the registered canonical context
   section is available without copied memory files.
