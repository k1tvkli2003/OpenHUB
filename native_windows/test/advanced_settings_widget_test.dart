import 'dart:io';

import 'package:openhub_windows/src/core/runtime/runtime_config.dart';
import 'package:openhub_windows/src/models/advanced_settings.dart';
import 'package:openhub_windows/src/state/app_controller.dart';
import 'package:openhub_windows/src/state/async_section.dart';
import 'package:openhub_windows/src/ui/app_theme.dart';
import 'package:openhub_windows/src/ui/features/advanced_settings_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sticky-session filters isolate native text input in a dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
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
    controller.stickySessions = const AsyncSection<StickySessionsPage>(
      phase: SectionPhase.ready,
      value: StickySessionsPage(
        entries: <StickySessionEntry>[],
        stalePromptCacheCount: 0,
        total: 0,
        hasMore: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AdvancedAdminSections(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Sticky sessions'));
    await tester.tap(find.text('Sticky sessions'));
    await tester.pumpAndSettle();

    expect(find.text('All accounts'), findsOneWidget);
    expect(find.text('All session keys'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('All accounts'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    final size = tester.getSize(find.byType(TextField));
    expect(size.height, inInclusiveRange(40, 80));
    expect(size.width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });
}
