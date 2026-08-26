import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/runtime/ox_bridge_supervisor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adopts only the exact healthy Ox bridge contract', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      if (request.uri.path == '/health') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'ok': true,
            'service': 'openhub-ox-adapter',
            'version': '3.6.0',
            'pid': 4242,
            'active_requests': 1,
            'token_usage_last_minute': <String, Object?>{'total_tokens': 12},
            'token_usage_last_hour': <String, Object?>{'total_tokens': 34},
          }),
        );
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    final temporary = await Directory.systemTemp.createTemp(
      'openhub-ox-adopt-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final script = await File(
      '${temporary.path}\\adapter.mjs',
    ).writeAsString('// fixture');
    final supervisor = OxBridgeSupervisor(portOwnerReader: (_) async => 4242);

    final runtime = await supervisor.start(
      bridgeScript: script,
      canonicalCodexHome: Directory('${temporary.path}\\.codex'),
      providerBaseUrl: Uri.parse('http://127.0.0.1:${server.port}/v1'),
    );

    expect(runtime.owned, isFalse);
    expect(runtime.health.activeRequests, 1);
    expect(runtime.health.tokenUsageLastMinute['total_tokens'], 12);
    await supervisor.stop();
  });

  test('rejects a health PID that does not own the Ox port', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'ok': true,
          'service': 'openhub-ox-adapter',
          'version': '3.6.0',
          'pid': 100,
          'active_requests': 0,
        }),
      );
      await request.response.close();
    });
    final temporary = await Directory.systemTemp.createTemp('openhub-ox-pid-');
    addTearDown(() => temporary.delete(recursive: true));
    final script = await File(
      '${temporary.path}\\adapter.mjs',
    ).writeAsString('// fixture');
    final supervisor = OxBridgeSupervisor(portOwnerReader: (_) async => 200);

    await expectLater(
      supervisor.start(
        bridgeScript: script,
        canonicalCodexHome: Directory('${temporary.path}\\.codex'),
        providerBaseUrl: Uri.parse('http://127.0.0.1:${server.port}/v1'),
      ),
      throwsA(isA<OxBridgeStartupException>()),
    );
  });
}
