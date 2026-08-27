import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/api/api_exception.dart';
import 'package:openhub_windows/src/core/api/local_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'supports CRUD verbs, repeated query values, cookies, and version pinning',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <_CapturedRequest>[];
      var issuedCookie = false;
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        requests.add(
          _CapturedRequest(
            method: request.method,
            path: request.uri.path,
            query: request.uri.queryParametersAll,
            body: body,
            cookie: request.headers.value(HttpHeaders.cookieHeader),
          ),
        );
        request.response.headers.set('X-App-Version', '2.0.0');
        if (!issuedCookie) {
          request.response.cookies.add(Cookie('dashboard_session', 'fixture'));
          issuedCookie = true;
        }
        if (request.method == 'DELETE') {
          request.response.statusCode = HttpStatus.noContent;
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(<String, Object?>{'ok': true}));
        }
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final client = LocalApiClient(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      addTearDown(client.close);

      await client.getObject(
        '/api/items',
        query: <String, Object?>{
          'accountId': <String>['a/1', 'b two'],
          'limit': 20,
          'ignored': null,
        },
      );
      await client.putObject(
        '/api/items/1',
        body: <String, Object?>{'enabled': true},
      );
      await client.patchObject(
        '/api/items/1',
        body: <String, Object?>{'name': 'updated'},
      );
      await client.deleteEmpty('/api/items/1');

      expect(client.lastAppVersion, '2.0.0');
      expect(requests.map((request) => request.method), <String>[
        'GET',
        'PUT',
        'PATCH',
        'DELETE',
      ]);
      expect(requests.first.query['accountId'], <String>['a/1', 'b two']);
      expect(requests.first.query['limit'], <String>['20']);
      expect(requests.first.query, isNot(contains('ignored')));
      expect(jsonDecode(requests[1].body), <String, Object?>{'enabled': true});
      expect(requests[1].cookie, contains('dashboard_session=fixture'));
      expect(requests[3].path, '/api/items/1');
    },
  );

  test('rejects query strings embedded in route text', () async {
    final client = LocalApiClient(endpoint: Uri.parse('http://127.0.0.1:2455'));
    addTearDown(client.close);

    expect(
      () => client.getObject('/api/items?unsafe=true'),
      throwsArgumentError,
    );
  });

  test(
    'uploads bounded multipart auth JSON without changing the bytes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? contentType;
      List<int>? received;
      server.listen((request) async {
        contentType = request.headers.value(HttpHeaders.contentTypeHeader);
        received = await request.fold<List<int>>(
          <int>[],
          (buffer, chunk) => buffer..addAll(chunk),
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(<String, Object?>{'imported': true}));
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final client = LocalApiClient(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      addTearDown(client.close);
      final source = utf8.encode('{"token":"fixture-only"}');

      final response = await client.postMultipartObject(
        '/api/accounts/import',
        fieldName: 'auth_json',
        filename: 'auth.json',
        bytes: source,
      );

      expect(response['imported'], isTrue);
      expect(contentType, startsWith('multipart/form-data;'));
      final wireText = utf8.decode(received!);
      expect(wireText, contains('name="auth_json"; filename="auth.json"'));
      expect(wireText, contains('{"token":"fixture-only"}'));
      expect(wireText, endsWith('--\r\n'));

      await expectLater(
        client.postMultipartObject(
          '/api/accounts/import',
          fieldName: 'auth_json',
          filename: 'auth.json',
          bytes: List<int>.filled(2 * 1024 * 1024 + 1, 0),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'upload_too_large',
          ),
        ),
      );
    },
  );
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
    required this.cookie,
  });

  final String method;
  final String path;
  final Map<String, List<String>> query;
  final String body;
  final String? cookie;
}
