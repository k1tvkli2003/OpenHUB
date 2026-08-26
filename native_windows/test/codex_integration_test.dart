import 'dart:io';

import 'package:openhub_windows/src/core/api/api_exception.dart';
import 'package:openhub_windows/src/core/runtime/runtime_config.dart';
import 'package:openhub_windows/src/models/auth_session.dart';
import 'package:openhub_windows/src/models/codex_integration.dart';
import 'package:openhub_windows/src/state/app_controller.dart';
import 'package:openhub_windows/src/state/async_section.dart';
import 'package:openhub_windows/src/ui/app_theme.dart';
import 'package:openhub_windows/src/ui/features/codex_integration_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> payload({bool enabled = false}) => <String, Object?>{
    'statePath': r'C:\Users\fixture\.openhub\openhub-managed-launch.json',
    'enabled': enabled,
    'revision': 4,
    'managedBaseUrl': 'http://127.0.0.1:2455/backend-api/codex-managed/v1',
    'toggledAt': '2026-08-10T12:00:00Z',
    'codexStatePolicy': 'never_mutate',
  };

  test('typed status accepts the HUB-owned zero-mutation contract', () {
    final status = CodexIntegrationStatus.fromJson(payload(enabled: true));

    expect(status.enabled, isTrue);
    expect(status.revision, 4);
    expect(status.codexStatePolicy, 'never_mutate');
    expect(status.managedBaseUrl, endsWith('/backend-api/codex-managed/v1'));
  });

  test('typed status rejects a policy that could mutate Codex state', () {
    final invalid = payload()..['codexStatePolicy'] = 'rewrite_config';

    expect(
      () => CodexIntegrationStatus.fromJson(invalid),
      throwsA(isA<ApiSchemaException>()),
    );
  });

  test(
    'typed profile registry accepts portable OpenAI Pool and Ox profiles',
    () {
      final registry = CodexProfileRegistry.fromJson(<String, Object?>{
        'statePath': r'C:\ProgramData\OpenHUB\openhub-profiles.json',
        'revision': 2,
        'activeProfileId': 'openai-pool',
        'changed': false,
        'profiles': <Object?>[
          <String, Object?>{
            'id': 'openai-pool',
            'label': 'OpenAI Pool',
            'kind': 'openai_pool',
            'modelProvider': 'openai',
            'model': 'gpt-5.6-sol',
            'wireApi': 'responses',
            'baseUrl': null,
            'catalogSource': 'live_managed',
            'catalogUri': null,
            'bridgeUri': null,
            'contextWindow': null,
            'accountRouting': 'automatic',
            'builtin': true,
          },
          <String, Object?>{
            'id': 'ox',
            'label': 'Ox',
            'kind': 'ox',
            'modelProvider': 'opencode_zen',
            'model': 'x-preview-f-free',
            'wireApi': 'responses',
            'baseUrl': 'http://127.0.0.1:17891/v1',
            'catalogSource': 'bundled',
            'catalogUri': 'asset://ox/opencode-ox.json',
            'bridgeUri': 'asset://ox/openhub-ox-adapter.mjs',
            'contextWindow': 1000000,
            'accountRouting': 'none',
            'builtin': true,
          },
        ],
      });

      expect(registry.activeProfile.label, 'OpenAI Pool');
      expect(registry.profiles, hasLength(2));
      expect(registry.profiles.last.baseUrl, contains('17891'));
    },
  );

  testWidgets('Settings owns Auto Route and documents account launch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController(
      config: RuntimeConfig(
        endpoint: Uri.parse('http://127.0.0.1:2455'),
        dataDirectory: Directory('${Directory.systemTemp.path}/openhub-test'),
        backupDirectory: Directory(
          '${Directory.systemTemp.path}/openhub-test-backups',
        ),
        backendExecutable: null,
        attachOnly: true,
      ),
    );
    addTearDown(controller.dispose);
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
      value: CodexIntegrationStatus.fromJson(payload(enabled: true)),
      lastSuccessfulFetch: DateTime.utc(2026, 8, 10, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                CodexIntegrationInfoPanel(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Disable Auto Route'), findsOneWidget);
    expect(find.text('Settings owns Auto Route'), findsOneWidget);
    expect(find.text('Open with a selected account'), findsNothing);
    expect(find.text('Accounts owns one-launch selection'), findsOneWidget);
    expect(
      find.textContaining('visible Codex login stays unchanged'),
      findsOneWidget,
    );
    expect(find.text('Codex data stays untouched'), findsOneWidget);
    expect(find.textContaining('Review and apply'), findsNothing);
    expect(find.textContaining('Restore backup'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
