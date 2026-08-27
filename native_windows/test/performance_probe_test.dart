import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/performance_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('probe is inert unless an explicit output file is configured', () {
    final probe = NativePerformanceProbe.fromEnvironment(
      environment: const <String, String>{},
    );

    expect(probe.enabled, isFalse);
    probe.markShellVisible();
    probe.markRuntimeActionable('ready');
  });

  test('probe records only bounded timing and state metadata', () {
    final directory = Directory.systemTemp.createTempSync(
      'openhub-native-probe-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final output = File('${directory.path}\\measurement.json');
    final probe = NativePerformanceProbe.fromEnvironment(
      environment: <String, String>{'OPENHUB_NATIVE_PERF_FILE': output.path},
    );

    probe.markShellVisible();
    probe.markRuntimeActionable('ready');

    final decoded =
        jsonDecode(output.readAsStringSync()) as Map<String, Object?>;
    expect(decoded.keys, <String>{
      'schemaVersion',
      'processStartedAt',
      'shellVisibleMs',
      'runtimeActionableMs',
      'runtimeState',
    });
    expect(decoded['runtimeState'], 'ready');
    expect(decoded['shellVisibleMs'], isA<num>());
    expect(decoded['runtimeActionableMs'], isA<num>());
  });
}
