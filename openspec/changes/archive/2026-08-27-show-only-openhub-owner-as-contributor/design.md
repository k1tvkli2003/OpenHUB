# Design

GitHub's contributor panel is calculated from the default branch commit graph,
not from README copy. Editing `.all-contributorsrc` alone therefore cannot
satisfy the requested public result.

The normalized `main` branch is created directly from the current index tree
with `git commit-tree` and no parent. Its author and committer are the verified
OpenHUB owner identity. Before updating `main`, the prior tip is retained under
a local-only recovery ref. Tree object equality is a hard gate before the
force-with-lease update, so the operation changes history attribution without
changing project files.

Published release tags remain immutable. The explicit README provenance block
continues to thank Codex LB and its contributors, which keeps upstream credit
separate from the OpenHUB contributor registry.
