import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../runtime/runtime_config.dart';
import 'api_exception.dart';
import 'json_readers.dart';

const _maximumResponseBytes = 16 * 1024 * 1024;
const _maximumUploadBytes = 2 * 1024 * 1024;

class LocalApiClient {
  LocalApiClient({
    required Uri endpoint,
    HttpClient? httpClient,
    this.requestTimeout = const Duration(seconds: 15),
  }) : endpoint = endpoint,
       _httpClient = httpClient ?? HttpClient() {
    RuntimeConfig.validateLoopbackEndpoint(endpoint);
    _httpClient.connectionTimeout = const Duration(seconds: 3);
    _httpClient.idleTimeout = const Duration(seconds: 20);
  }

  final Uri endpoint;
  final Duration requestTimeout;
  final HttpClient _httpClient;
  final Map<String, Cookie> _cookies = <String, Cookie>{};
  String? _lastAppVersion;

  String? get lastAppVersion => _lastAppVersion;

  Future<Map<String, Object?>> getObject(
    String route, {
    Map<String, Object?>? query,
    Duration? timeout,
  }) async {
    final value = await _request(
      method: 'GET',
      route: route,
      query: query,
      timeout: timeout,
    );
    return readObject(value, route);
  }

  Future<List<Object?>> getList(
    String route, {
    Map<String, Object?>? query,
    Duration? timeout,
  }) async {
    final value = await _request(
      method: 'GET',
      route: route,
      query: query,
      timeout: timeout,
    );
    return readList(value, route);
  }

  Future<Map<String, Object?>> postObject(
    String route, {
    Object? body,
    Duration? timeout,
  }) async {
    final value = await _request(
      method: 'POST',
      route: route,
      body: body,
      timeout: timeout,
    );
    return readObject(value, route);
  }

  Future<Map<String, Object?>> putObject(
    String route, {
    Object? body,
    Duration? timeout,
  }) async {
    final value = await _request(
      method: 'PUT',
      route: route,
      body: body,
      timeout: timeout,
    );
    return readObject(value, route);
  }

  Future<Map<String, Object?>> patchObject(
    String route, {
    Object? body,
    Duration? timeout,
  }) async {
    final value = await _request(
      method: 'PATCH',
      route: route,
      body: body,
      timeout: timeout,
    );
    return readObject(value, route);
  }

  Future<Map<String, Object?>> deleteObject(
    String route, {
    Map<String, Object?>? query,
    Object? body,
    Duration? timeout,
  }) async {
    final value = await _request(
      method: 'DELETE',
      route: route,
      query: query,
      body: body,
      timeout: timeout,
    );
    return readObject(value, route);
  }

  Future<void> deleteEmpty(
    String route, {
    Map<String, Object?>? query,
    Object? body,
    Duration? timeout,
  }) async {
    await _request(
      method: 'DELETE',
      route: route,
      query: query,
      body: body,
      timeout: timeout,
      allowEmpty: true,
    );
  }

  Future<void> postEmpty(
    String route, {
    Object? body,
    Duration? timeout,
  }) async {
    await _request(
      method: 'POST',
      route: route,
      body: body,
      timeout: timeout,
      allowEmpty: true,
    );
  }

  Future<Map<String, Object?>> postMultipartObject(
    String route, {
    required String fieldName,
    required String filename,
    required List<int> bytes,
    ContentType? fileContentType,
    Duration? timeout,
  }) async {
    if (bytes.length > _maximumUploadBytes) {
      throw const ApiException(
        message: 'The selected import exceeds the 2 MiB safety limit.',
        code: 'upload_too_large',
      );
    }
    if (!_safeMultipartToken.hasMatch(fieldName) ||
        filename.contains(RegExp(r'[\r\n"]'))) {
      throw ArgumentError('Unsafe multipart field name or filename.');
    }
    final boundary = _multipartBoundary();
    final builder = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="$fieldName"; '
          'filename="$filename"\r\n'
          'Content-Type: '
          '${(fileContentType ?? ContentType.json).mimeType}\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final value = await _request(
      method: 'POST',
      route: route,
      rawBody: builder.takeBytes(),
      rawContentType: ContentType(
        'multipart',
        'form-data',
        parameters: <String, String>{'boundary': boundary},
      ),
      timeout: timeout,
    );
    return readObject(value, route);
  }

  Future<Object?> _request({
    required String method,
    required String route,
    Map<String, Object?>? query,
    Object? body,
    List<int>? rawBody,
    ContentType? rawContentType,
    Duration? timeout,
    bool allowEmpty = false,
  }) async {
    if (!route.startsWith('/')) {
      throw ArgumentError.value(
        route,
        'route',
        'API routes must start with /.',
      );
    }
    if (route.contains('?') || route.contains('#')) {
      throw ArgumentError.value(
        route,
        'route',
        'API routes must not contain a query string or fragment.',
      );
    }
    final uri = endpoint.replace(path: route, query: _encodeQuery(query));

    try {
      final request = await _httpClient
          .openUrl(method, uri)
          .timeout(timeout ?? requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_cookies.isNotEmpty) {
        request.cookies.addAll(_cookies.values);
      }
      if (body != null && rawBody != null) {
        throw ArgumentError('A request cannot contain JSON and raw bodies.');
      }
      if (rawBody != null) {
        request.headers.contentType = rawContentType;
        request.add(rawBody);
      } else if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(timeout ?? requestTimeout);
      final appVersion = response.headers.value('x-app-version')?.trim();
      if (appVersion != null && appVersion.isNotEmpty) {
        _lastAppVersion = appVersion;
      }
      for (final cookie in response.cookies) {
        if (cookie.maxAge == 0) {
          _cookies.remove(cookie.name);
        } else {
          _cookies[cookie.name] = cookie;
        }
      }
      final bytes = await _readBounded(
        response,
      ).timeout(timeout ?? requestTimeout);
      final payloadText = utf8.decode(bytes, allowMalformed: false);
      final Object? payload = payloadText.trim().isEmpty
          ? null
          : jsonDecode(payloadText);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _decodeError(response.statusCode, payload);
      }
      if (payload == null && !allowEmpty) {
        throw ApiSchemaException('$method $route returned an empty response.');
      }
      return payload;
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException(
        message: 'Timed out while contacting the local openhub service.',
        code: 'timeout',
        details: error,
      );
    } on SocketException catch (error) {
      throw ApiException(
        message: 'The local openhub service is not reachable.',
        code: 'network_error',
        details: error,
      );
    } on FormatException catch (error) {
      throw ApiSchemaException(
        '$method $route returned invalid JSON.',
        details: error,
      );
    } on HttpException catch (error) {
      throw ApiException(
        message: 'Local HTTP request failed: ${error.message}',
        code: 'network_error',
        details: error,
      );
    }
  }

  static final RegExp _safeMultipartToken = RegExp(r'^[A-Za-z0-9_-]+$');

  String _multipartBoundary() {
    final random = Random.secure();
    final suffix = List<int>.generate(
      18,
      (_) => random.nextInt(256),
      growable: false,
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'openhub-native-$suffix';
  }

  String? _encodeQuery(Map<String, Object?>? query) {
    if (query == null || query.isEmpty) {
      return null;
    }
    final pairs = <String>[];
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      final values = value is Iterable && value is! String
          ? value
          : <Object?>[value];
      for (final item in values) {
        if (item == null) {
          continue;
        }
        pairs.add(
          '${Uri.encodeQueryComponent(entry.key)}='
          '${Uri.encodeQueryComponent(item.toString())}',
        );
      }
    }
    return pairs.isEmpty ? null : pairs.join('&');
  }

  Future<Uint8List> _readBounded(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response) {
      received += chunk.length;
      if (received > _maximumResponseBytes) {
        throw const ApiException(
          message:
              'Local API response exceeded the native client safety limit.',
          code: 'response_too_large',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  ApiException _decodeError(int statusCode, Object? payload) {
    String? code;
    String? message;
    Object? details;
    if (payload is Map) {
      final error = payload['error'];
      if (error is Map) {
        code = error['code'] is String ? error['code'] as String : null;
        message = error['message'] is String
            ? error['message'] as String
            : null;
        details = error;
      }
    }
    return ApiException(
      message: message ?? 'Local API request failed with HTTP $statusCode.',
      code: code ?? 'request_failed',
      statusCode: statusCode,
      details: details ?? payload,
    );
  }

  void close({bool force = false}) {
    _httpClient.close(force: force);
  }
}
