import 'dart:io';

import 'package:path/path.dart' as path;

const _defaultPort = 2455;
const _bundledBackendName = 'openhub-backend.exe';

class RuntimeConfigException implements Exception {
  const RuntimeConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RuntimeConfig {
  RuntimeConfig({
    required this.endpoint,
    required this.dataDirectory,
    required this.backupDirectory,
    required this.backendExecutable,
    required this.attachOnly,
    this.launchCodexOnReady = false,
    this.startupTimeout = const Duration(seconds: 20),
  }) {
    validateLoopbackEndpoint(endpoint);
    if (startupTimeout <= Duration.zero) {
      throw const RuntimeConfigException('Startup timeout must be positive.');
    }
  }

  final Uri endpoint;
  final Directory dataDirectory;
  final Directory backupDirectory;
  final File? backendExecutable;
  final bool attachOnly;
  final bool launchCodexOnReady;
  final Duration startupTimeout;

  int get port => endpoint.port == 0 ? _defaultPort : endpoint.port;

  static RuntimeConfig fromEnvironment({
    required List<String> arguments,
    Map<String, String>? environment,
    String? resolvedExecutable,
  }) {
    final env = environment ?? Platform.environment;
    final parsedArguments = _parseArguments(arguments);
    final profile = env['USERPROFILE'];
    if (profile == null || profile.trim().isEmpty) {
      throw const RuntimeConfigException(
        'USERPROFILE is unavailable; the local openhub data directory cannot be resolved safely.',
      );
    }

    final endpointText =
        parsedArguments['endpoint'] ??
        env['OPENHUB_NATIVE_ENDPOINT'] ??
        'http://127.0.0.1:$_defaultPort';
    final endpoint = Uri.tryParse(endpointText);
    if (endpoint == null) {
      throw RuntimeConfigException('Invalid local endpoint: $endpointText');
    }
    validateLoopbackEndpoint(endpoint);

    final dataPath =
        parsedArguments['data-dir'] ??
        env['OPENHUB_DATA_DIR'] ??
        path.join(profile, '.openhub');
    final backupPath =
        parsedArguments['backup-dir'] ??
        env['OPENHUB_NATIVE_BACKUP_DIR'] ??
        path.join(profile, '.openhub-backups');

    final explicitBackend =
        parsedArguments['backend'] ?? env['OPENHUB_NATIVE_BACKEND'];
    final executablePath = resolvedExecutable ?? Platform.resolvedExecutable;
    final bundledBackend = File(
      path.join(
        File(executablePath).parent.path,
        'backend',
        _bundledBackendName,
      ),
    );
    final backend = explicitBackend == null || explicitBackend.trim().isEmpty
        ? (bundledBackend.existsSync() ? bundledBackend : null)
        : File(path.normalize(path.absolute(explicitBackend)));

    final attachOnly =
        parsedArguments.containsKey('attach-only') ||
        _parseBoolean(env['OPENHUB_NATIVE_ATTACH_ONLY']) ||
        backend == null;
    final launchCodexOnReady =
        parsedArguments.containsKey('launch-codex') ||
        _parseBoolean(env['OPENHUB_NATIVE_LAUNCH_CODEX']);

    final timeoutSeconds =
        int.tryParse(
          parsedArguments['startup-timeout-seconds'] ??
              env['OPENHUB_NATIVE_STARTUP_TIMEOUT_SECONDS'] ??
              '',
        ) ??
        20;

    return RuntimeConfig(
      endpoint: endpoint,
      dataDirectory: Directory(path.normalize(path.absolute(dataPath))),
      backupDirectory: Directory(path.normalize(path.absolute(backupPath))),
      backendExecutable: backend,
      attachOnly: attachOnly,
      launchCodexOnReady: launchCodexOnReady,
      startupTimeout: Duration(seconds: timeoutSeconds),
    );
  }

  static void validateLoopbackEndpoint(Uri endpoint) {
    if (endpoint.scheme != 'http') {
      throw const RuntimeConfigException(
        'The native management endpoint must use loopback HTTP.',
      );
    }
    if (endpoint.userInfo.isNotEmpty ||
        endpoint.query.isNotEmpty ||
        endpoint.fragment.isNotEmpty) {
      throw const RuntimeConfigException(
        'The native management endpoint cannot contain credentials, a query, or a fragment.',
      );
    }
    if (endpoint.path.isNotEmpty && endpoint.path != '/') {
      throw const RuntimeConfigException(
        'The native management endpoint must not contain a path prefix.',
      );
    }

    final normalizedHost = endpoint.host.toLowerCase();
    final literal = InternetAddress.tryParse(normalizedHost);
    final isLoopback =
        normalizedHost == 'localhost' || (literal?.isLoopback ?? false);
    if (!isLoopback) {
      throw RuntimeConfigException(
        'Refusing non-loopback native management endpoint: ${endpoint.host}',
      );
    }
    if (endpoint.port < 1 || endpoint.port > 65535) {
      throw RuntimeConfigException(
        'Native management endpoint port must be between 1 and 65535: ${endpoint.port}',
      );
    }
  }
}

Map<String, String?> _parseArguments(List<String> arguments) {
  final parsed = <String, String?>{};
  for (final argument in arguments) {
    if (!argument.startsWith('--')) {
      throw RuntimeConfigException(
        'Unexpected native client argument: $argument',
      );
    }
    final value = argument.substring(2);
    final equals = value.indexOf('=');
    if (equals == -1) {
      if (!{'attach-only', 'launch-codex'}.contains(value)) {
        throw RuntimeConfigException(
          'Argument requires --name=value form: $argument',
        );
      }
      parsed[value] = null;
      continue;
    }
    final key = value.substring(0, equals);
    final item = value.substring(equals + 1);
    if (!{
      'endpoint',
      'data-dir',
      'backup-dir',
      'backend',
      'startup-timeout-seconds',
    }.contains(key)) {
      throw RuntimeConfigException('Unknown native client argument: --$key');
    }
    if (item.trim().isEmpty) {
      throw RuntimeConfigException(
        'Native client argument cannot be empty: --$key',
      );
    }
    parsed[key] = item;
  }
  return parsed;
}

bool _parseBoolean(String? value) {
  return switch (value?.trim().toLowerCase()) {
    '1' || 'true' || 'yes' || 'on' => true,
    _ => false,
  };
}
