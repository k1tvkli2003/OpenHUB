## 1. Backend recovery

- [x] 1.1 Stop treating a bare usage HTTP 404 as permanent deactivation.
- [x] 1.2 Retry only exact legacy generic-404 deactivations and bypass stale
      cached usage for that recovery attempt.
- [x] 1.3 Recover a successful legacy row with a compare-and-set into the quota
      status derived from fresh upstream windows.

## 2. Native Accounts refresh

- [x] 2.1 Trigger a bounded live usage refresh when Accounts is selected while
      preserving cached-first rendering and refresh single-flight behavior.

## 3. Verification

- [x] 3.1 Add backend regression tests for transient 404 classification,
      legacy retry, successful recovery, and fail-closed permanent signals.
- [x] 3.2 Add a Flutter controller regression for Accounts destination refresh.
- [x] 3.3 Run focused and full relevant backend/Flutter verification.
- [x] 3.4 Build, install, and probe the real OpenHUB runtime.
