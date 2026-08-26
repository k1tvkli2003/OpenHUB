import 'package:openhub_windows/src/core/runtime/codex_pulse_service.dart';
import 'package:openhub_windows/src/models/codex_pulse.dart';
import 'package:openhub_windows/src/models/runtime_control.dart';
import 'package:openhub_windows/src/ui/app_theme.dart';
import 'package:openhub_windows/src/ui/features/codex_pulse_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Pulse renders live task signals and opens the selected task', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = _FakePulseSource(_snapshot());
    String? openedTask;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: CodexPulsePage(
            source: source,
            onOpenTask: (id) async => openedTask = id,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);

    expect(find.text('OpenHUB Pulse'), findsOneWidget);
    expect(find.text('gpt-5.6-sol'), findsWidgets);
    expect(find.text('OpenAI'), findsWidgets);
    expect(find.text('2 Ox adapter active'), findsOneWidget);
    expect(find.text('Agent runtimes'), findsOneWidget);
    expect(find.text('Hermes'), findsWidgets);
    expect(find.text('OpenCode'), findsWidgets);
    expect(find.text('kimi-k2.7'), findsWidgets);
    expect(find.text('x-preview-f-free'), findsWidgets);
    expect(find.text('750,000'), findsOneWidget);
    expect(find.text('Repair provider bridge'), findsOneWidget);
    expect(find.text('1,200'), findsWidgets);
    expect(find.text('Reasoning · inferred'), findsNothing);
    expect(find.text('Reasoning'), findsWidgets);

    await tester.tap(find.text('Repair provider bridge'));
    await tester.pump();
    expect(openedTask, '01a034bd-4062-7c40-80d2-407627226790');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Pulse delegates provider changes to its source', (tester) async {
    tester.view.physicalSize = const Size(1360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = _FakePulseSource(_snapshot());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: CodexPulsePage(source: source)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Ox'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(source.switchedTo, CodexProviderMode.ox);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Pulse keeps its signal ledger readable at compact width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final source = _FakePulseSource(_snapshot());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: CodexPulsePage(source: source)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    expect(find.text('Repair provider bridge'), findsOneWidget);
    expect(find.text('Task signal ledger'), findsOneWidget);
    expect(find.text('3 waiting'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('12.0 MiB / 24.0 MiB'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

CodexPulseSnapshot _snapshot() {
  final now = DateTime.utc(2026, 8, 24, 18, 30);
  return CodexPulseSnapshot(
    tasks: <CodexTaskSignal>[
      CodexTaskSignal(
        id: '01a034bd-4062-7c40-80d2-407627226790',
        title: 'Repair provider bridge',
        model: 'gpt-5.6-sol',
        provider: 'OpenAI',
        phase: CodexTaskPhase.reasoning,
        totalTokens: 92800,
        sessionTokens: 860,
        lastActivityAt: now,
        startedAt: now.subtract(const Duration(minutes: 4)),
        reasoningEffort: 'max',
        contextTokens: 72120,
        contextWindow: 258400,
      ),
      CodexTaskSignal(
        id: 'hermes-session-1',
        sessionId: 'hermes-session-1',
        cwd: r'C:\workspace\hermes',
        title: 'Hermes research turn',
        model: 'kimi-k2.7',
        provider: 'Nous',
        phase: CodexTaskPhase.active,
        totalTokens: 148000,
        sessionTokens: 12000,
        lastActivityAt: now,
        startedAt: now.subtract(const Duration(minutes: 2)),
        runtime: AgentRuntime.hermes,
        capabilities: const RuntimeTaskCapabilities(
          open: true,
          pause: false,
          resume: true,
          stop: true,
        ),
      ),
      CodexTaskSignal(
        id: 'ses_openhub',
        sessionId: 'ses_openhub',
        cwd: r'C:\workspace\opencode',
        title: 'OpenCode adapter',
        model: 'x-preview-f-free',
        provider: 'OpenCode Zen',
        phase: CodexTaskPhase.idle,
        totalTokens: 220901221,
        sessionTokens: 874000,
        lastActivityAt: now.subtract(const Duration(minutes: 7)),
        startedAt: now.subtract(const Duration(hours: 3)),
        runtime: AgentRuntime.opencode,
        capabilities: const RuntimeTaskCapabilities(
          open: true,
          pause: false,
          resume: false,
          stop: true,
        ),
      ),
    ],
    usage: CodexPulseUsage(
      sinceStart: 3840,
      lastMinute: 1200,
      lastHour: 3840,
      startedAt: now.subtract(const Duration(minutes: 12)),
    ),
    bridge: const CodexBridgeStatus(
      reachable: true,
      healthy: true,
      supportsMetrics: true,
      activeRequests: 2,
      requests: <CodexBridgeRequest>[],
      version: '3.3.0',
      model: 'x-preview-f-free',
      provider: 'opencode_zen',
      queuedRequests: 3,
      admissionLimit: 2,
      admissionMaximum: 4,
      inFlightBytes: 12 * 1024 * 1024,
      byteBudgetBytes: 24 * 1024 * 1024,
    ),
    profileMode: CodexProviderMode.openai,
    profileModel: 'gpt-5.6-sol',
    sampledAt: now,
    runtimeHealth: <RuntimeHealth>[
      const RuntimeHealth(
        runtime: AgentRuntime.codex,
        status: 'available',
        databasePath: r'C:\Users\fixture\.codex\state.sqlite',
      ),
      const RuntimeHealth(
        runtime: AgentRuntime.hermes,
        status: 'available',
        databasePath: r'C:\Users\fixture\hermes\state.db',
        gatewayReachable: true,
      ),
      const RuntimeHealth(
        runtime: AgentRuntime.opencode,
        status: 'available',
        databasePath: r'C:\Users\fixture\opencode\opencode.db',
        gatewayReachable: true,
      ),
    ],
    runtimeUsage: RuntimeUsageSummary(
      total: RuntimeUsageWindow(
        sinceStart: 221053061,
        lastMinute: 752200,
        lastHour: 6440000,
        startedAt: now.subtract(const Duration(hours: 3)),
      ),
      codex: RuntimeUsageWindow(
        sinceStart: 3840,
        lastMinute: 1200,
        lastHour: 3840,
        startedAt: now.subtract(const Duration(minutes: 12)),
      ),
      hermes: RuntimeUsageWindow(
        sinceStart: 148000,
        lastMinute: 1000,
        lastHour: 126000,
        startedAt: now.subtract(const Duration(hours: 1)),
      ),
      opencode: RuntimeUsageWindow(
        sinceStart: 220901221,
        lastMinute: 750000,
        lastHour: 6310160,
        startedAt: now.subtract(const Duration(hours: 3)),
      ),
    ),
  );
}

class _FakePulseSource implements CodexPulseSource {
  _FakePulseSource(this.snapshot);

  final CodexPulseSnapshot snapshot;
  CodexProviderMode? switchedTo;

  @override
  DateTime get sessionStartedAt => snapshot.usage.startedAt;

  @override
  void dispose() {}

  @override
  Future<CodexPulseSnapshot> refresh() async => snapshot;

  @override
  Future<ProviderSwitchResult> switchProvider(CodexProviderMode mode) async {
    switchedTo = mode;
    return ProviderSwitchResult.success('Switched to ${mode.label}.');
  }
}
