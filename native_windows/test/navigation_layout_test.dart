import 'dart:io';

import 'package:openhub_windows/src/core/runtime/runtime_config.dart';
import 'package:openhub_windows/src/models/auth_session.dart';
import 'package:openhub_windows/src/state/app_controller.dart';
import 'package:openhub_windows/src/state/async_section.dart';
import 'package:openhub_windows/src/ui/app_theme.dart';
import 'package:openhub_windows/src/ui/native_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expanded navigation stays complete at a short desktop height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(
      config: RuntimeConfig(
        endpoint: Uri.parse('http://127.0.0.1:2455'),
        dataDirectory: Directory('${Directory.systemTemp.path}/openhub-nav'),
        backupDirectory: Directory(
          '${Directory.systemTemp.path}/openhub-nav-backups',
        ),
        backendExecutable: null,
        attachOnly: true,
      ),
    );
    addTearDown(controller.dispose);
    controller.runtime = const RuntimeViewState(phase: RuntimePhase.ready);
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

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: NativeWorkspace(controller: controller),
      ),
    );
    await tester.pump();

    const labels = <String>[
      'Pulse',
      'Accounts',
      'Traffic',
      'API access',
      'Automations',
      'Settings',
      'Local runtime',
    ];
    for (final label in labels) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: '$label must remain in the rail');
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(0), reason: '$label is clipped');
      expect(rect.bottom, lessThanOrEqualTo(600), reason: '$label is clipped');
    }

    expect(
      tester.getRect(find.text('Automations')).bottom,
      lessThan(tester.getRect(find.text('Settings')).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact bottom navigation includes Pulse without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(620, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(
      config: RuntimeConfig(
        endpoint: Uri.parse('http://127.0.0.1:2455'),
        dataDirectory: Directory('${Directory.systemTemp.path}/openhub-nav'),
        backupDirectory: Directory(
          '${Directory.systemTemp.path}/openhub-nav-backups',
        ),
        backendExecutable: null,
        attachOnly: true,
      ),
    );
    addTearDown(controller.dispose);
    controller.runtime = const RuntimeViewState(phase: RuntimePhase.ready);
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

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: NativeWorkspace(controller: controller),
      ),
    );
    await tester.pump();

    for (final label in const <String>[
      'Pulse',
      'Accounts',
      'Traffic',
      'API access',
      'Automations',
      'Settings',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
