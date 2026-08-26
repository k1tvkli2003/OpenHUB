import 'package:openhub_windows/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unsafe configuration renders a blocking native error surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const OpenHubApp(
        config: null,
        configurationError: FormatException('unsafe endpoint'),
      ),
    );

    expect(find.text('Native startup was blocked'), findsOneWidget);
    expect(find.textContaining('No backend was started'), findsOneWidget);
    expect(find.textContaining('unsafe endpoint'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
