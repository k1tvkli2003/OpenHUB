import 'package:openhub_windows/src/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expanded brand lockup keeps the approved live identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: OpenHubBrandLockup()),
      ),
    );

    expect(find.text('OpenHUB'), findsOneWidget);
    expect(find.text('Local account router'), findsOneWidget);
    expect(find.byType(OpenHubMark), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(image.filterQuality, FilterQuality.high);
    expect(image.isAntiAlias, isTrue);
  });

  testWidgets('compact brand mark remains labeled without duplicate copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: OpenHubBrandLockup(compact: true)),
      ),
    );

    expect(find.byType(OpenHubMark), findsOneWidget);
    expect(find.text('OpenHUB'), findsNothing);
    expect(find.byType(Tooltip), findsOneWidget);
  });
}
