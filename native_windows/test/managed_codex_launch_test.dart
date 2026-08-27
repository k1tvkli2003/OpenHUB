import 'dart:io';

import 'package:openhub_windows/src/core/api/local_api_client.dart';
import 'package:openhub_windows/src/core/runtime/codex_desktop_launcher.dart';
import 'package:openhub_windows/src/core/runtime/runtime_config.dart';
import 'package:openhub_windows/src/data/openhub_repository.dart';
import 'package:openhub_windows/src/models/auth_session.dart';
import 'package:openhub_windows/src/models/codex_integration.dart';
import 'package:openhub_windows/src/state/app_controller.dart';
import 'package:openhub_windows/src/state/async_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Auto route verifies the prepared account before managed launch',
    () async {
      final events = <String>[];
      final route = _route(revision: 8);
      final repository = _LaunchRepository(
        events: events,
        route: route,
        preparation: _preparation(route),
        integration: _integration(enabled: true),
      );
      final launcher = _FakeLauncher(events: events);
      final controller = _controller(
        repository,
        launcher,
        route,
        enabled: true,
      );
      addTearDown(() {
        controller.dispose();
        repository.close();
      });

      final outcome = await controller.openCodex();

      expect(
        outcome?.disposition,
        CodexManagedLaunchDisposition.launchedManaged,
      );
      expect(outcome?.route.accountId, 'account-best');
      expect(events, <String>[
        'inspect',
        'capability',
        'prepare:auto',
        'readback',
        'launch:managed',
      ]);
    },
  );

  test('routing off opens Codex normally without preparation', () async {
    final events = <String>[];
    final route = _route(revision: 0, prepared: false);
    final repository = _LaunchRepository(
      events: events,
      route: route,
      preparation: _preparation(_route(revision: 1)),
      integration: _integration(enabled: false),
    );
    final launcher = _FakeLauncher(events: events);
    final controller = _controller(repository, launcher, route, enabled: false);
    addTearDown(() {
      controller.dispose();
      repository.close();
    });

    final outcome = await controller.openCodex();

    expect(outcome?.disposition, CodexManagedLaunchDisposition.launchedNormal);
    expect(events, <String>['inspect', 'launch:normal']);
  });

  test('manual account launch works while Auto route remains off', () async {
    final events = <String>[];
    final route = _route(
      revision: 3,
      accountId: 'account-manual',
      selectionMode: 'manual',
    );
    final repository = _LaunchRepository(
      events: events,
      route: route,
      preparation: _preparation(route),
      integration: _integration(enabled: false),
    );
    final launcher = _FakeLauncher(events: events);
    final controller = _controller(
      repository,
      launcher,
      _route(revision: 2),
      enabled: false,
    );
    addTearDown(() {
      controller.dispose();
      repository.close();
    });

    final outcome = await controller.openCodex(
      manualAccountId: 'account-manual',
    );

    expect(outcome?.disposition, CodexManagedLaunchDisposition.launchedManaged);
    expect(outcome?.route.selectionMode, 'manual');
    expect(controller.codexIntegration.value?.enabled, isFalse);
    expect(events, <String>[
      'inspect',
      'capability',
      'prepare:account-manual',
      'readback',
      'launch:managed',
    ]);
  });

  test('already-running Codex is never prepared or launched twice', () async {
    final events = <String>[];
    final route = _route(revision: 7);
    final repository = _LaunchRepository(
      events: events,
      route: route,
      preparation: _preparation(route),
      integration: _integration(enabled: true),
    );
    final launcher = _FakeLauncher(events: events, running: true);
    final controller = _controller(repository, launcher, route, enabled: true);
    controller.lastCodexLaunchPreparation = _preparation(route);
    controller.codexLaunchActionError = StateError('stale launch failure');
    addTearDown(() {
      controller.dispose();
      repository.close();
    });

    final outcome = await controller.openCodex();

    expect(outcome?.disposition, CodexManagedLaunchDisposition.alreadyRunning);
    expect(controller.lastCodexLaunchPreparation, isNull);
    expect(controller.codexLaunchActionError, isNull);
    expect(events, <String>['inspect', 'focus']);
  });

  test(
    'confirmed restart stops Codex before preparing a manual route',
    () async {
      final events = <String>[];
      final route = _route(
        revision: 8,
        accountId: 'account-manual',
        selectionMode: 'manual',
      );
      final repository = _LaunchRepository(
        events: events,
        route: route,
        preparation: _preparation(route),
        integration: _integration(enabled: true),
      );
      final launcher = _FakeLauncher(events: events, running: true);
      final controller = _controller(
        repository,
        launcher,
        route,
        enabled: true,
      );
      addTearDown(() {
        controller.dispose();
        repository.close();
      });

      final outcome = await controller.restartCodex(
        manualAccountId: 'account-manual',
      );

      expect(
        outcome?.disposition,
        CodexManagedLaunchDisposition.launchedManaged,
      );
      expect(events, <String>[
        'stop',
        'inspect',
        'capability',
        'prepare:account-manual',
        'readback',
        'launch:managed',
      ]);
    },
  );

  test('background-only Codex blocks managed preparation', () async {
    final events = <String>[];
    final route = _route(revision: 7);
    final repository = _LaunchRepository(
      events: events,
      route: route,
      preparation: _preparation(route),
      integration: _integration(enabled: true),
    );
    final launcher = _FakeLauncher(
      events: events,
      running: true,
      focusable: false,
    );
    final controller = _controller(repository, launcher, route, enabled: true);
    addTearDown(() {
      controller.dispose();
      repository.close();
    });

    final outcome = await controller.openCodex();

    expect(outcome, isNull);
    expect(
      controller.codexLaunchActionError.toString(),
      contains('still running in the background'),
    );
    expect(events, <String>['inspect', 'focus']);
  });

  test('routing off can reactivate a background-only Codex instance', () async {
    final events = <String>[];
    final route = _route(revision: 0, prepared: false);
    final repository = _LaunchRepository(
      events: events,
      route: route,
      preparation: _preparation(_route(revision: 1)),
      integration: _integration(enabled: false),
    );
    final launcher = _FakeLauncher(
      events: events,
      running: true,
      focusable: false,
    );
    final controller = _controller(repository, launcher, route, enabled: false);
    addTearDown(() {
      controller.dispose();
      repository.close();
    });

    final outcome = await controller.openCodex();

    expect(outcome?.disposition, CodexManagedLaunchDisposition.launchedNormal);
    expect(events, <String>['inspect', 'focus', 'launch:normal']);
  });

  test('read-back mismatch fails closed before Windows launch', () async {
    final events = <String>[];
    final prepared = _route(revision: 8);
    final repository = _LaunchRepository(
      events: events,
      route: _route(revision: 9, accountId: 'unexpected-account'),
      preparation: _preparation(prepared),
      integration: _integration(enabled: true),
    );
    final launcher = _FakeLauncher(events: events);
    final controller = _controller(
      repository,
      launcher,
      _route(revision: 7),
      enabled: true,
    );
    addTearDown(() {
      controller.dispose();
      repository.close();
    });

    final outcome = await controller.openCodex();

    expect(outcome, isNull);
    expect(controller.codexLaunchActionError, isA<StateError>());
    expect(events, <String>[
      'inspect',
      'capability',
      'prepare:auto',
      'readback',
    ]);
  });

  test(
    'enabling Auto route capability-gates before HUB state changes',
    () async {
      final events = <String>[];
      final route = _route(revision: 0, prepared: false);
      final repository = _LaunchRepository(
        events: events,
        route: route,
        preparation: _preparation(_route(revision: 1)),
        integration: _integration(enabled: false),
      );
      final launcher = _FakeLauncher(events: events);
      final controller = _controller(
        repository,
        launcher,
        route,
        enabled: false,
      );
      addTearDown(() {
        controller.dispose();
        repository.close();
      });

      final mutation = await controller.setCodexManagedRoutingEnabled(true);

      expect(mutation?.status.enabled, isTrue);
      expect(events, <String>['capability', 'mode:true', 'inspect']);
    },
  );
}

AppController _controller(
  _LaunchRepository repository,
  _FakeLauncher launcher,
  CodexLaunchRoute route, {
  required bool enabled,
}) {
  final root = Directory.systemTemp;
  final controller = AppController(
    config: RuntimeConfig(
      endpoint: Uri.parse('http://127.0.0.1:2455'),
      dataDirectory: Directory('${root.path}/openhub-launch-test'),
      backupDirectory: Directory('${root.path}/openhub-launch-test-backups'),
      backendExecutable: null,
      attachOnly: true,
    ),
    repository: repository,
    codexDesktopLauncher: launcher,
  );
  controller.auth = const AsyncSection<AuthSession>(
    phase: SectionPhase.ready,
    value: AuthSession(
      authenticated: true,
      passwordRequired: false,
      totpRequiredOnLogin: false,
      totpConfigured: false,
      bootstrapRequired: false,
      bootstrapTokenConfigured: false,
      authMode: 'loopback',
      passwordManagementEnabled: true,
      passwordSessionActive: true,
      role: 'admin',
      permissions: <String>{'read', 'write'},
      guestAccessEnabled: false,
      guestPasswordRequired: false,
    ),
  );
  controller.codexIntegration = AsyncSection<CodexIntegrationStatus>(
    phase: SectionPhase.ready,
    value: _integration(enabled: enabled),
  );
  controller.codexLaunchRoute = AsyncSection<CodexLaunchRoute>(
    phase: SectionPhase.ready,
    value: route,
  );
  return controller;
}

CodexLaunchRoute _route({
  required int revision,
  bool prepared = true,
  String accountId = 'account-best',
  String selectionMode = 'auto',
}) {
  return CodexLaunchRoute(
    prepared: prepared,
    selectionMode: prepared ? selectionMode : null,
    accountId: prepared ? accountId : null,
    accountLabel: prepared ? 'Selected account' : null,
    accountEmail: prepared ? 'selected@example.invalid' : null,
    planType: prepared ? 'plus' : null,
    effectiveRemainingPercent: prepared ? 82 : null,
    primaryRemainingPercent: prepared ? 82 : null,
    secondaryRemainingPercent: prepared ? 91 : null,
    monthlyRemainingPercent: null,
    limitingRemainingCredits: null,
    sampledAt: prepared ? DateTime.utc(2026, 8, 10, 14) : null,
    preparedAt: prepared ? DateTime.utc(2026, 8, 10, 14, 1) : null,
    revision: revision,
  );
}

CodexLaunchPreparation _preparation(CodexLaunchRoute route) {
  return CodexLaunchPreparation(
    readyToLaunch: true,
    changed: true,
    route: route,
    candidates: <CodexLaunchCandidate>[
      CodexLaunchCandidate(
        accountId: route.accountId!,
        accountLabel: route.accountLabel!,
        accountEmail: route.accountEmail!,
        planType: route.planType!,
        effectiveRemainingPercent: route.effectiveRemainingPercent!,
        primaryRemainingPercent: route.primaryRemainingPercent!,
        secondaryRemainingPercent: route.secondaryRemainingPercent,
        monthlyRemainingPercent: route.monthlyRemainingPercent,
        limitingRemainingCredits: route.limitingRemainingCredits,
        sampledAt: route.sampledAt!,
      ),
    ],
    exclusions: const <CodexLaunchExclusion>[],
  );
}

CodexIntegrationStatus _integration({required bool enabled}) {
  return CodexIntegrationStatus(
    statePath: r'C:\Users\fixture\.openhub\openhub-managed-launch.json',
    enabled: enabled,
    revision: enabled ? 2 : 1,
    managedBaseUrl: 'http://127.0.0.1:2455/backend-api/codex-managed/v1',
    toggledAt: DateTime.utc(2026, 8, 10),
    codexStatePolicy: 'never_mutate',
  );
}

class _LaunchRepository extends OpenHubRepository {
  _LaunchRepository._({
    required this.events,
    required this.route,
    required this.preparation,
    required this.integration,
    required LocalApiClient client,
  }) : _client = client,
       super(client);

  factory _LaunchRepository({
    required List<String> events,
    required CodexLaunchRoute route,
    required CodexLaunchPreparation preparation,
    required CodexIntegrationStatus integration,
  }) {
    final client = LocalApiClient(endpoint: Uri.parse('http://127.0.0.1:1'));
    return _LaunchRepository._(
      events: events,
      route: route,
      preparation: preparation,
      integration: integration,
      client: client,
    );
  }

  final List<String> events;
  final CodexLaunchRoute route;
  final CodexLaunchPreparation preparation;
  CodexIntegrationStatus integration;
  final LocalApiClient _client;

  @override
  Future<CodexLaunchPreparation> prepareCodexLaunch(
    CodexLaunchRoute current, {
    String? accountId,
  }) async {
    events.add('prepare:${accountId ?? 'auto'}');
    return preparation;
  }

  @override
  Future<CodexLaunchRoute> getCodexLaunchRoute() async {
    events.add('readback');
    return route;
  }

  @override
  Future<CodexIntegrationMutation> setCodexManagedRoutingEnabled(
    CodexIntegrationStatus current, {
    required bool enabled,
  }) async {
    events.add('mode:$enabled');
    integration = _integration(enabled: enabled);
    return CodexIntegrationMutation(status: integration, changed: true);
  }

  void close() => _client.close();
}

class _FakeLauncher implements CodexDesktopLauncher {
  _FakeLauncher({required this.events, this.running = false, bool? focusable})
    : focusable = focusable ?? running;

  final List<String> events;
  bool running;
  final bool focusable;

  @override
  Future<bool> isRunning() async {
    events.add('inspect');
    return running;
  }

  @override
  Future<bool> focusRunning() async {
    events.add('focus');
    return focusable;
  }

  @override
  Future<bool> stopRunningForRestart() async {
    events.add('stop');
    running = false;
    return true;
  }

  @override
  Future<CodexDesktopCapability> inspectManagedCapability() async {
    events.add('capability');
    return const CodexDesktopCapability(
      supported: true,
      packageVersion: '26.803.5235.0',
      executablePath:
          r'C:\Program Files\WindowsApps\OpenAI.Codex\app\ChatGPT.exe',
      applicationId: 'App',
    );
  }

  @override
  Future<CodexDesktopLaunchResult> launch({
    Uri? managedBaseUrl,
    Uri? appServerWebSocketUrl,
  }) async {
    events.add(
      'launch:${managedBaseUrl == null && appServerWebSocketUrl == null ? 'normal' : 'managed'}',
    );
    return CodexDesktopLaunchResult(
      launched: true,
      alreadyRunning: false,
      managed: managedBaseUrl != null || appServerWebSocketUrl != null,
      applicationId: 'App',
    );
  }
}
