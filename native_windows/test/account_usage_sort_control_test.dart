import 'dart:io';

import 'package:openhub_windows/src/core/runtime/runtime_config.dart';
import 'package:openhub_windows/src/models/account_summary.dart';
import 'package:openhub_windows/src/state/app_controller.dart';
import 'package:openhub_windows/src/ui/app_theme.dart';
import 'package:openhub_windows/src/ui/features/account_usage_sort_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remaining-usage control changes the global account order', (
    tester,
  ) async {
    final controller = AppController(
      config: RuntimeConfig(
        endpoint: Uri.parse('http://127.0.0.1:1'),
        dataDirectory: Directory('${Directory.systemTemp.path}/openhub-sort'),
        backupDirectory: Directory(
          '${Directory.systemTemp.path}/openhub-sort-backups',
        ),
        backendExecutable: null,
        attachOnly: true,
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(child: AccountUsageSortControl(controller: controller)),
        ),
      ),
    );

    expect(find.text('Usage left · high → low'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<AccountRemainingUsageOrder>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usage left · low → high').last);
    await tester.pumpAndSettle();

    expect(
      controller.accountRemainingUsageOrder,
      AccountRemainingUsageOrder.lowestFirst,
    );
    expect(find.text('Usage left · low → high'), findsOneWidget);
  });
}
