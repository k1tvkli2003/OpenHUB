## 1. Contributor ownership

- [x] 1.1 Replace the inherited project contributor registry with the verified
      OpenHUB owner account only.
- [x] 1.2 Keep upstream contributors credited exclusively in the existing
      license/provenance/thanks section.
- [x] 1.3 Repair documentation links that still target now-archived change
      folders.

## 2. Safe history normalization

- [ ] 2.1 Verify the repository is clean and synchronized, record the current
      tip in a local recovery ref, and create an owner-authored root commit from
      the exact current tree.
- [ ] 2.2 Prove old and new tree hashes are identical, then update `main` with
      force-with-lease without moving any release tag.
- [ ] 2.3 Verify GitHub reports only `k1tvkli2003` as a default-branch
      contributor and that stable release assets and provenance remain valid.

## 3. Publication gates

- [x] 3.1 Run strict OpenSpec, public identity, contributor-registry, docs, and
      workflow validation.
- [ ] 3.2 Wait for the normalized main CI and Pages deployment, then archive
      this completed change.
