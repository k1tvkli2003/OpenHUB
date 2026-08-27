## Verification record

Date: 2026-08-24

### Outcome

Codex Pulse is integrated into the existing native Windows OpenHUB. No second
monitoring executable is installed. The stable installed application exposes
the live task ledger, semantic heartbeat, current profile, OpenAI and Ox task
models, context use, session token deltas, rolling token windows, safe provider
controls, validated task deep links, and Ox bridge health/metrics.

### Source and regression verification

- `flutter analyze`: no issues.
- Full Flutter test suite: 91 tests passed and one environment-dependent test
  skipped.
- Focused Pulse widget suite: three tests passed.
- Deterministic tests cover read-only state discovery, bounded rollout parsing,
  lifecycle states, positive token windows, reset handling, bridge metrics,
  deep-link UUID validation, responsive rendering, reduced motion, navigation,
  and provider-switch process delegation.
- Provider-switch isolation tests passed:
  `PROVIDER_SWITCH_SMOKE_OK` and
  `PROVIDER_SWITCH_ORDINAL_REPAIR_SMOKE_OK`.
- Adapter parity tests passed:
  `ADAPTER_PROVIDER_PARITY_SMOKE_OK`, `ADAPTER_ANTHROPIC_SMOKE_OK`,
  `ADAPTER_TOOL_VISUAL_SMOKE_OK`, and `OX_VISION_NETWORK_SMOKE_OK`.
- Real Ox-through-Codex probes completed native `exec`, freeform
  `apply_patch`, and catalog-v1 multi-agent spawn/wait flows. Catalog v2 was
  rejected after runtime testing because it caused empty wait loops with this
  provider; the shipped v1 contract is the verified working path.
- The adapter parity harness verifies ordered steering input, compacted history,
  assistant and custom-tool history, collaboration tool forwarding,
  `additional_tools` forwarding for `automation_update`, cancellation cleanup,
  bounded retry, live streaming, and `fc_*` function-call IDs.

### Windows artifact and runtime verification

- Installed executable:
  `C:\Program Files\OpenHUB\App\OpenHUB.exe`
- Stable release archive:
  `C:\Program Files\OpenHUB\Release\OpenHUB-Windows-1.22.0.zip`
- Installed and packaged executable SHA-256:
  `721E31D499E17F31F28EBAC4F5D2EFE9CE5C1141FAC1D71FCE6C6BF1AB9A5424`
- Installed and packaged archive SHA-256:
  `55A5F7A94E69D756F75FBE1552485E073C5A32B4B5D9BD5A82505BA6162D7A28`
- Installed backend readiness returned HTTP 200 with database and managed-route
  protocol checks healthy.
- The installed build launched without elevation through the `asInvoker`
  manifest.
- Desktop and per-user Start Menu shortcuts both target the stable installed
  executable. The companion `OpenHUB - Open Codex` shortcuts retain the
  `--launch-codex` argument.
- Release performance probe:
  shell visible 11.304 ms, runtime actionable 4361.811 ms, account-scroll p95
  work 2.793 ms, and frame-budget result `true`.

### Visual/runtime evidence

- `work/qa/codex-pulse-wide-release-20260824.jpg`
- `work/qa/codex-pulse-medium-release-20260824.jpg`
- `work/qa/codex-pulse-compact-release-20260824.jpg`
- `work/qa/codex-pulse-installed-final-20260824.jpg`
- `work/qa/codex-pulse-installed-provider-bridge-20260824.jpg`
- `work/qa/codex-pulse-installed-bridge-detail-20260824.jpg`

The final installed runtime visibly showed the OpenAI profile, a live
`gpt-5.6-sol` task, mixed OpenAI/Ox recent tasks, an explicit `Ox active` badge,
safe provider controls, bridge version 3.3.0, model `x-preview-f-free`, active
inference count, and detailed one-minute/one-hour bridge token counters.

### Remaining bounded limitations

- One historical rollout still contains a duplicate ordinal at its locked tail.
  The exact task already resumes correctly after its malformed function-call
  IDs were repaired. A validated pending repair is installed and will shift the
  duplicate and following ordinals on the next normal provider switch/relaunch
  after Codex Desktop is fully stopped; mutating that live file now would be
  unsafe.
- The adapter's scheduled-task relay is verified with Codex-compatible
  `additional_tools` input. This host session did not expose a live
  `automation_update` action, so creating a real scheduled task through Ox was
  not claimed as end-to-end proof.
- When an upstream request omits a Codex thread ID, Pulse reports it accurately
  in the aggregate Ox-active badge and bridge panel but does not guess which
  task row owns it.
- Session token accounting intentionally begins from the counters observed when
  Pulse starts. Existing pre-session usage remains visible only through the
  bridge rolling windows and is not mislabeled as Pulse-session consumption.

## 2026-08-25 local load-control follow-up

### Outcome

- Installed Ox bridge `3.6.0` now admits logical requests through a
  cancellation-aware FIFO queue with an adaptive `1..6` slot range, four-slot
  initial limit, and 24 MiB aggregate serialized-request budget.
- Retryable overload/network failures reduce shared capacity and open a bounded
  cooldown; successful logical completions restore one slot gradually. A
  request retains one admission lease across its retries and stream recovery.
- Large tool outputs are compacted only when a later result is byte-for-byte
  identical to an earlier result in the same request. The first full result is
  retained; unique conversation, file, tool, compaction, and multi-agent
  content remains untouched.
- Pulse now shows Queued as a semantic live phase and exposes active slots,
  queue depth, adaptive range, in-flight request bytes, byte budget, and
  cooldown state. Its bounded task/token/rollout caches are pruned to the
  current recent-task set.

### Verification

- Adapter syntax and integration:
  `ADAPTER_PROVIDER_PARITY_SMOKE_OK`, `ADAPTER_ADMISSION_SMOKE_OK`,
  `ADAPTER_ANTHROPIC_SMOKE_OK`, and `ADAPTER_TOOL_VISUAL_SMOKE_OK`.
- The admission harness proved a two-slot burst ceiling, byte-budget queuing,
  queued-request cancellation, retry recovery after a 503, and adaptive limit
  reduction. The parity harness proved exact duplicate-output compaction while
  retaining the first full result and tool ordering.
- Live installed bridge probe returned HTTP 200 with a real function call,
  `LIVE_ADMISSION_OK`, a completed Responses stream, and 276 reported tokens.
- `flutter analyze`: no issues. Focused Pulse tests: 8 passed. Full native test
  suite: 93 passed and one explicitly environment-dependent test skipped.
- Release performance regressions remained green; cached navigation worst case
  was 1.685 ms in the full test run.
- Strict OpenSpec validation passed for this change; all 47 repository specs
  passed strict validation.
- Installed executable and packaged executable SHA-256 both equal
  `81F24F981E910A0E2A552F631122AB2A39C3BBE13EA38A12C9D6FF55130A76B6`.
  Installed and source release archives both equal
  `41A03B68F2D4B35F93A70736F03B1798F5F3395F740BD76719C9B7CA550393A6`.
- Live installed UI inspection showed bridge version `3.6.0`, model
  `x-preview-f-free`, `0 / 4` active slots, `0 waiting`, adaptive range `4 / 6`,
  `0 B / 24.0 MiB`, cooldown `Ready`, and detailed telemetry. The Accounts
  launch refresh also completed with 17 current and 0 failed accounts.
- Desktop and Start Menu shortcuts still target the stable installed
  executable; managed shortcuts retain `--launch-codex`.

### Boundaries

- The stateless upstream Chat Completions contract still requires complete
  conversation context on each turn. Cross-turn delta-only transfer was not
  faked; only provably exact duplicate tool results are compacted.
- No GitHub Actions workflow was added because this checkout has no configured
  Git remote and the requested work is local-only for now.
- Historical backups, sessions, and SQLite free pages were not deleted or
  vacuumed; those remain separate destructive maintenance choices.
