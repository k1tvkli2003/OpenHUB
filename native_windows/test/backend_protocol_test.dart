import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/api/api_exception.dart';
import 'package:openhub_windows/src/core/api/local_api_client.dart';
import 'package:openhub_windows/src/data/openhub_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the required managed-route backend protocol', () async {
    final fixture = await _ReadyFixture.start(protocol: '2');
    addTearDown(fixture.close);

    await fixture.repository.requireReady();
  });

  test('rejects an older sidecar sharing the public release version', () async {
    final fixture = await _ReadyFixture.start();
    addTearDown(fixture.close);

    await expectLater(
      fixture.repository.requireReady(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'backend_protocol_mismatch')
            .having(
              (error) => error.message,
              'message',
              contains('Fully exit the older OpenHUB'),
            ),
      ),
    );
  });
}

class _ReadyFixture {
  _ReadyFixture(this.server, this.client)
    : repository = OpenHubRepository(client);

  final HttpServer server;
  final LocalApiClient client;
  final OpenHubRepository repository;

  static Future<_ReadyFixture> start({String? protocol}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set(
        'X-App-Version',
        OpenHubRepository.compatibleBackendVersion,
      );
      request.response.write(
        jsonEncode(<String, Object?>{
          'status': 'ok',
          'checks': <String, Object?>{
            'database': 'ok',
            'openhub_managed_route_protocol': ?protocol,
          },
        }),
      );
      await request.response.close();
    });
    final client = LocalApiClient(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    return _ReadyFixture(server, client);
  }

  Future<void> close() async {
    client.close();
    await server.close(force: true);
  }
}
