## 1. Contracts and data model

- [x] 1.1 Add typed task, bridge, usage-window, and snapshot models.
- [x] 1.2 Add a read-only service for state DB discovery, bounded rollout tails,
      lifecycle inference, context use, profile mode, and bridge metrics.
- [x] 1.3 Add session-baseline and rolling minute/hour token accounting.

## 2. Native OpenHUB integration

- [x] 2.1 Add Pulse to native navigation and lifecycle-safe refresh behavior.
- [x] 2.2 Implement the Signal Ledger page, heartbeat, states, responsive task
      rows, empty/degraded views, reduced motion, and manual refresh.
- [x] 2.3 Add validated Codex task deep links through the Windows bridge.
- [x] 2.4 Add provider controls that invoke only the existing safe switcher.

## 3. Verification and delivery

- [x] 3.1 Add deterministic parser, token-window, bridge, deep-link, widget, and
      navigation regressions.
- [x] 3.2 Run Dart formatting, Flutter analysis, focused tests, and full native
      tests in an isolated host-load window.
- [x] 3.3 Build and launch the Windows artifact, capture Pulse at wide and
      compact sizes, and compare it with the recorded visual direction.
- [x] 3.4 Install the validated build into the existing stable OpenHUB path and
      verify shortcuts still target the stable executable.
- [x] 3.5 Record OpenSpec verification evidence and remaining limitations.

## 4. Local Ox performance and resilience

- [x] 4.1 Add cancellation-aware adaptive admission with concurrency and
      serialized-byte budgets across Responses and Anthropic bridge traffic.
- [x] 4.2 Add shared overload cooldown, gradual recovery, and one-time request
      serialization across bounded retries.
- [x] 4.3 Deduplicate only exact repeated large tool outputs while retaining the
      first full copy and recording aggregate savings.
- [x] 4.4 Expose queue, slot, byte-pressure, and cooldown telemetry through
      bridge health/metrics and Codex Pulse, including a semantic Queued phase.
- [x] 4.5 Add burst, cancellation, duplicate-output, parser, and widget
      regressions; run provider, OpenSpec, Flutter, build, install, and live
      bridge verification.
