## Verification

Verified on 2026-08-25 against the installed Windows package and the live local
OpenHUB backend.

### Automated checks

- `ruff check app/modules/usage/updater.py tests/unit/test_usage_updater.py`:
  passed.
- `pytest tests/unit/test_usage_updater.py`: 100 passed.
- Focused native Accounts/startup Flutter tests: 5 passed.
- `flutter analyze`: no issues found.
- `npx --yes @fission-ai/openspec@latest validate --specs`: 47 specs
  passed, 0 failed.
- Provider switch smoke suite: passed, including the version-matched OpenAI
  model catalog and Sol/Terra/Luna visibility checks.
- Release performance probe with 250 synthetic Accounts rows: shell visible in
  11.466 ms, runtime actionable in 60.946 ms, scroll p95 work 3.206 ms, worst
  work 12.713 ms, and within the 16.67 ms frame budget.

The full Flutter suite reached 90 passing tests before its debug/JIT-only
performance guard measured a 37.669-41.174 ms scroll p95 against a 35 ms debug
threshold. The fresh release-mode probe above is the product runtime gate and
passes comfortably. The broader backend Accounts/API selection reported 70
passes and one unrelated existing display-name assertion (`Alias` versus the
email fallback); no production display-name behavior was changed here.

### Installed runtime evidence

- Built and transactionally installed `OpenHUB-Windows-1.22.0` under
  `C:\Program Files\OpenHUB\App`.
- Installed `/health/ready` returned HTTP 200 with database ready, managed route
  protocol 2, and a healthy bridge ring.
- The startup refresh recovered all 17 rows carrying the exact legacy generic
  404 deactivation reason. Live state after refresh: 11 active, 4 rate-limited,
  2 quota-exceeded, 2 re-authentication-required, and 0 legacy generic-404
  deactivations. The two re-authentication rows retain explicit invalid-token
  evidence and were intentionally not revived.
- The installed Accounts surface rendered 19 accounts with fresh quota samples
  and no refresh failures. Account deletion remains available from the account
  detail panel behind its confirmation flow; no real account was deleted.
