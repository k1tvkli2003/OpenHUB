import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'windows_platform_bridge.dart';

typedef OxNodeResolver = Future<File> Function();
typedef OxBridgeProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments,
      Map<String, String> environment,
      String workingDirectory,
    );
typedef OxBridgeProcessBinder = Future<void> Function(int processId);
typedef OxBridgePortOwnerReader = Future<int?> Function(int port);

class OxBridgeHealth {
  const OxBridgeHealth({
    required this.service,
    required this.version,
    required this.processId,
    required this.activeRequests,
    required this.tokenUsageLastMinute,
    required this.tokenUsageLastHour,
    required this.raw,
  });

  final String service;
  final String version;
  final int processId;
  final int activeRequests;
  final Map<String, Object?> tokenUsageLastMinute;
  final Map<String, Object?> tokenUsageLastHour;
  final Map<String, Object?> raw;

  factory OxBridgeHealth.fromJson(Map<String, Object?> json) {
    final service = json['service'];
    final version = json['version'];
    final processId = json['pid'];
    final activeRequests = json['active_requests'];
    if (json['ok'] != true ||
        service is! String ||
        service != 'openhub-ox-adapter' ||
        version is! String ||
        version.isEmpty ||
        processId is! int ||
        processId < 1 ||
        activeRequests is! int ||
        activeRequests < 0) {
      throw const FormatException('Ox bridge health contract is invalid.');
    }
    return OxBridgeHealth(
      service: service,
      version: version,
      processId: processId,
      activeRequests: activeRequests,
      tokenUsageLastMinute: _objectOrEmpty(json['token_usage_last_minute']),
      tokenUsageLastHour: _objectOrEmpty(json['token_usage_last_hour']),
      raw: Map<String, Object?>.unmodifiable(json),
    );
  }
}

class OxBridgeRuntime {
  const OxBridgeRuntime({
    required this.endpoint,
    required this.health,
    required this.owned,
  });

  final Uri endpoint;
  final OxBridgeHealth health;
  final bool owned;
}

class OxBridgeStartupException implements Exception {
  const OxBridgeStartupException(
    this.message, {
    this.diagnostics = const <String>[],
  });

  final String message;
  final List<String> diagnostics;

  @override
  String toString() => message;
}

class OxBridgeSupervisor {
  OxBridgeSupervisor({
    OxNodeResolver? nodeResolver,
    OxBridgeProcessStarter? processStarter,
    OxBridgeProcessBinder? processBinder,
    OxBridgePortOwnerReader? portOwnerReader,
    this.startupTimeout = const Duration(seconds: 20),
  }) : _nodeResolver = nodeResolver ?? _resolveNodeExecutable,
       _processStarter = processStarter ?? _startProcess,
       _processBinder =
           processBinder ?? const WindowsPlatformBridge().bindOwnedProcess,
       _portOwnerReader = portOwnerReader ?? _readLoopbackPortOwner;

  final OxNodeResolver _nodeResolver;
  final OxBridgeProcessStarter _processStarter;
  final OxBridgeProcessBinder _processBinder;
  final OxBridgePortOwnerReader _portOwnerReader;
  final Duration startupTimeout;
  final List<String> _diagnostics = <String>[];

  Process? _process;
  OxBridgeRuntime? _runtime;
  Future<OxBridgeRuntime>? _starting;

  OxBridgeRuntime? get runtime => _runtime;
  List<String> get diagnostics => List<String>.unmodifiable(_diagnostics);

  Future<OxBridgeRuntime> start({
    required File bridgeScript,
    required Directory canonicalCodexHome,
    required Uri providerBaseUrl,
  }) {
    final current = _runtime;
    final endpoint = _bridgeEndpoint(providerBaseUrl);
    if (current != null && current.endpoint == endpoint) {
      return Future<OxBridgeRuntime>.value(current);
    }
    if (current != null) {
      return Future<OxBridgeRuntime>.error(
        StateError('A different Ox bridge endpoint is already active.'),
      );
    }
    return _starting ??= _start(
      bridgeScript: bridgeScript,
      canonicalCodexHome: canonicalCodexHome,
      endpoint: endpoint,
    ).whenComplete(() => _starting = null);
  }

  Future<OxBridgeRuntime> _start({
    required File bridgeScript,
    required Directory canonicalCodexHome,
    required Uri endpoint,
  }) async {
    _diagnostics.clear();
    if (!bridgeScript.isAbsolute || !await bridgeScript.exists()) {
      throw OxBridgeStartupException(
        'Packaged Ox bridge script is missing: ${bridgeScript.path}',
      );
    }
    if (!canonicalCodexHome.isAbsolute) {
      throw const OxBridgeStartupException(
        'The canonical Codex home is invalid.',
      );
    }

    final existing = await _readHealth(endpoint);
    if (existing != null) {
      final owner = await _portOwnerReader(endpoint.port);
      if (owner != null && owner != existing.processId) {
        throw OxBridgeStartupException(
          'Ox health PID ${existing.processId} does not own loopback port ${endpoint.port}.',
        );
      }
      final runtime = OxBridgeRuntime(
        endpoint: endpoint,
        health: existing,
        owned: false,
      );
      _runtime = runtime;
      return runtime;
    }
    final unexpectedOwner = await _portOwnerReader(endpoint.port);
    if (unexpectedOwner != null) {
      throw OxBridgeStartupException(
        'Loopback port ${endpoint.port} is already owned by process $unexpectedOwner.',
      );
    }

    final node = await _nodeResolver();
    if (!node.isAbsolute ||
        path.windows.basename(node.path).toLowerCase() != 'node.exe' ||
        !await node.exists()) {
      throw OxBridgeStartupException(
        'A trusted Node.js runtime was not found: ${node.path}',
      );
    }
    final environment = Map<String, String>.from(Platform.environment)
      ..['CODEX_HOME'] = canonicalCodexHome.path
      ..['OPENHUB_OX_BRIDGE_PORT'] = endpoint.port.toString();
    final process = await _processStarter(
      node.path,
      <String>[bridgeScript.path],
      environment,
      bridgeScript.parent.path,
    );
    _process = process;
    try {
      await _processBinder(process.pid);
    } on Object catch (error) {
      await _terminate(process);
      _process = null;
      throw OxBridgeStartupException(
        'The Ox bridge could not be bound to OpenHUB ownership: $error',
      );
    }
    _captureDiagnostics(process.stdout, 'ox');
    _captureDiagnostics(process.stderr, 'ox-error');

    final deadline = DateTime.now().add(startupTimeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      if (await _hasExited(process)) {
        _process = null;
        throw OxBridgeStartupException(
          'The Ox bridge exited before becoming ready.',
          diagnostics: diagnostics,
        );
      }
      try {
        final owner = await _portOwnerReader(endpoint.port);
        if (owner != null && owner != process.pid) {
          throw OxBridgeStartupException(
            'Ox loopback port ${endpoint.port} is owned by unexpected process $owner.',
          );
        }
        final health = await _readHealth(endpoint);
        if (health != null && health.processId == process.pid) {
          final runtime = OxBridgeRuntime(
            endpoint: endpoint,
            health: health,
            owned: true,
          );
          _runtime = runtime;
          return runtime;
        }
      } on OxBridgeStartupException {
        await _terminate(process);
        _process = null;
        rethrow;
      } on Object catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await _terminate(process);
    _process = null;
    throw OxBridgeStartupException(
      'The Ox bridge did not become ready before the timeout.${lastError == null ? '' : ' Last error: $lastError'}',
      diagnostics: diagnostics,
    );
  }

  Future<OxBridgeHealth?> refreshHealth() async {
    final current = _runtime;
    if (current == null) {
      return null;
    }
    final health = await _readHealth(current.endpoint);
    if (health == null) {
      _runtime = null;
      return null;
    }
    _runtime = OxBridgeRuntime(
      endpoint: current.endpoint,
      health: health,
      owned: current.owned,
    );
    return health;
  }

  Future<void> stop() async {
    final current = _runtime;
    final process = _process;
    _runtime = null;
    _process = null;
    if (current?.owned != true || process == null) {
      return;
    }
    try {
      await _postShutdown(current!.endpoint);
      await process.exitCode.timeout(const Duration(seconds: 4));
    } on Object {
      await _terminate(process);
    }
  }

  void _captureDiagnostics(Stream<List<int>> source, String label) {
    source.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      final sanitized = _sanitize(line);
      if (sanitized.isEmpty) {
        return;
      }
      _diagnostics.add('[$label] $sanitized');
      if (_diagnostics.length > 80) {
        _diagnostics.removeAt(0);
      }
    });
  }
}

Uri _bridgeEndpoint(Uri providerBaseUrl) {
  if (providerBaseUrl.scheme != 'http' ||
      providerBaseUrl.host != '127.0.0.1' ||
      !providerBaseUrl.hasPort ||
      providerBaseUrl.userInfo.isNotEmpty ||
      providerBaseUrl.hasQuery ||
      providerBaseUrl.hasFragment) {
    throw const OxBridgeStartupException(
      'Ox provider endpoint must use numeric loopback HTTP.',
    );
  }
  return providerBaseUrl.replace(path: '', query: null, fragment: null);
}

Future<OxBridgeHealth?> _readHealth(Uri endpoint) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
  try {
    final request = await client
        .getUrl(endpoint.replace(path: '/health'))
        .timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 2));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }
    final bytes = await response
        .fold<List<int>>(<int>[], (buffer, chunk) {
          if (buffer.length + chunk.length > 256 * 1024) {
            throw const FormatException('Ox health response is too large.');
          }
          return buffer..addAll(chunk);
        })
        .timeout(const Duration(seconds: 2));
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Ox health response is not an object.');
    }
    return OxBridgeHealth.fromJson(decoded.cast<String, Object?>());
  } on SocketException {
    return null;
  } on TimeoutException {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<void> _postShutdown(Uri endpoint) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
  try {
    final request = await client
        .postUrl(endpoint.replace(path: '/shutdown'))
        .timeout(const Duration(seconds: 2));
    request.contentLength = 0;
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>();
  } finally {
    client.close(force: true);
  }
}

Future<File> _resolveNodeExecutable() async {
  final configured = Platform.environment['OPENHUB_NODE_PATH']?.trim();
  if (configured != null && configured.isNotEmpty) {
    final candidate = File(configured).absolute;
    if (await candidate.exists()) {
      return candidate;
    }
  }
  final result = await Process.run('where.exe', const <String>[
    'node.exe',
  ], runInShell: false);
  if (result.exitCode == 0) {
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final candidate = File(line.trim()).absolute;
      if (await candidate.exists()) {
        return candidate;
      }
    }
  }
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    final runtimeRoot = Directory(
      path.join(localAppData, 'OpenAI', 'Codex', 'runtimes', 'cua_node'),
    );
    if (await runtimeRoot.exists()) {
      final candidates = <File>[];
      await for (final entry in runtimeRoot.list(followLinks: false)) {
        if (entry is Directory) {
          final candidate = File(path.join(entry.path, 'bin', 'node.exe'));
          if (await candidate.exists()) {
            candidates.add(candidate.absolute);
          }
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((left, right) => right.path.compareTo(left.path));
        return candidates.first;
      }
    }
  }
  throw const OxBridgeStartupException(
    'Node.js was not found. Install Codex Desktop or a supported Node.js runtime.',
  );
}

Future<Process> _startProcess(
  String executable,
  List<String> arguments,
  Map<String, String> environment,
  String workingDirectory,
) {
  return Process.start(
    executable,
    arguments,
    environment: environment,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.normal,
    runInShell: false,
  );
}

Future<int?> _readLoopbackPortOwner(int port) async {
  final result = await Process.run('powershell.exe', <String>[
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    r'$connection = Get-NetTCPConnection -LocalAddress 127.0.0.1 -State Listen -ErrorAction SilentlyContinue | '
        "Where-Object LocalPort -eq $port | Select-Object -First 1; if (\$null -ne \$connection) { Write-Output \$connection.OwningProcess }",
  ], runInShell: false);
  if (result.exitCode != 0) {
    return null;
  }
  return int.tryParse(result.stdout.toString().trim());
}

Future<bool> _hasExited(Process process) {
  return Future.any<bool>(<Future<bool>>[
    process.exitCode.then((_) => true),
    Future<bool>.delayed(const Duration(milliseconds: 1), () => false),
  ]);
}

Future<void> _terminate(Process process) async {
  process.kill(ProcessSignal.sigterm);
  try {
    await process.exitCode.timeout(const Duration(seconds: 4));
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode.timeout(const Duration(seconds: 2));
  }
}

Map<String, Object?> _objectOrEmpty(Object? value) => value is Map
    ? Map<String, Object?>.unmodifiable(value.cast<String, Object?>())
    : const <String, Object?>{};

String _sanitize(String value) {
  var result = value.replaceAll(
    RegExp(
      r'(authorization|api[_-]?key|token)\s*[:=]\s*[^\s,}]+',
      caseSensitive: false,
    ),
    r'$1=[redacted]',
  );
  if (result.length > 1000) {
    result = '${result.substring(0, 1000)}...';
  }
  return result;
}
