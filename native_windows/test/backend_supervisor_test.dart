import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/api/local_api_client.dart';
import 'package:openhub_windows/src/core/runtime/backend_supervisor.dart';
import 'package:openhub_windows/src/core/runtime/runtime_config.dart';
import 'package:openhub_windows/src/data/openhub_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics redact bootstrap, bearer, API-key, and JWT material', () {
    final sanitized = sanitizeBackendDiagnostic(
      'bootstrap_token: super-secret '
      'Authorization: Bearer bearer-value '
      'api_key=sk-1234567890abcdef '
      'id_token=eyJheader.payload.signature',
    );

    expect(sanitized, isNot(contains('super-secret')));
    expect(sanitized, isNot(contains('bearer-value')));
    expect(sanitized, isNot(contains('1234567890abcdef')));
    expect(sanitized, isNot(contains('eyJheader.payload.signature')));
    expect(sanitized, contains('[redacted]'));
  });

  test(
    'occupied incompatible port fails before backup or child startup',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(<String, Object?>{'status': 'ok'}));
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });
      final root = await Directory.systemTemp.createTemp(
        'openhub-supervisor-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final endpoint = Uri.parse('http://127.0.0.1:${server.port}');
      final client = LocalApiClient(endpoint: endpoint);
      addTearDown(client.close);
      final supervisor = BackendSupervisor(
        RuntimeConfig(
          endpoint: endpoint,
          dataDirectory: Directory('${root.path}/data'),
          backupDirectory: Directory('${root.path}/backups'),
          backendExecutable: File('${root.path}/never-started.exe'),
          attachOnly: false,
        ),
        OpenHubRepository(client),
      );

      await expectLater(
        supervisor.ensureReady(),
        throwsA(
          isA<BackendStartupException>().having(
            (error) => error.message,
            'message',
            allOf(contains('occupied'), contains('No backup')),
          ),
        ),
      );
      expect(Directory('${root.path}/backups').existsSync(), isFalse);
      expect(supervisor.ownsProcess, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );

  test(
    'occupied older OpenHUB sidecar surfaces an actionable exit message',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.headers.set('X-App-Version', '2.0.0');
        request.response.write(
          jsonEncode(<String, Object?>{
            'status': 'ok',
            'checks': <String, Object?>{'database': 'ok'},
          }),
        );
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });
      final root = await Directory.systemTemp.createTemp(
        'openhub-older-sidecar-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final endpoint = Uri.parse('http://127.0.0.1:${server.port}');
      final client = LocalApiClient(endpoint: endpoint);
      addTearDown(client.close);
      final supervisor = BackendSupervisor(
        RuntimeConfig(
          endpoint: endpoint,
          dataDirectory: Directory('${root.path}/data'),
          backupDirectory: Directory('${root.path}/backups'),
          backendExecutable: File('${root.path}/never-started.exe'),
          attachOnly: false,
        ),
        OpenHubRepository(client),
      );

      await expectLater(
        supervisor.ensureReady(),
        throwsA(
          isA<BackendStartupException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('older OpenHUB build'),
              contains('Fully exit the older OpenHUB'),
              contains('No backup or child process was started'),
            ),
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(seconds: 8)),
  );
}
