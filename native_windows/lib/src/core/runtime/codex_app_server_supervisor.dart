import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'codex_app_server_client.dart';
import 'windows_platform_bridge.dart';

const _allowedEnvironmentOverrides = <String>{
  'CODEX_APP_SERVER_CHATGPT_BASE_URL',
  'CODEX_APP_SERVER_OPENAI_BASE_URL',
};

typedef CodexExecutableResolver = Future<File> Function();
typedef CodexAppServerProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments,
      Map<String, String> environment,
      String workingDirectory,
    );
typedef CodexProcessBinder = Future<void> Function(int processId);
typedef CodexPortAllocator = Future<int> Function();
typedef CodexPortOwnerReader = Future<int?> Function(int port);

class CodexAppServerLaunchOptions {
  CodexAppServerLaunchOptions({
    required this.profileId,
    required this.canonicalCodexHome,
    this.cliExecutable,
    this.configOverrides = const <String>[],
    this.environmentOverrides = const <String, String>{},
  }) {
    final normalizedProfileId = profileId.trim();
    if (normalizedProfileId.isEmpty || normalizedProfileId.length > 128) {
      throw ArgumentError.value(profileId, 'profileId', 'Invalid profile id.');
    }
    if (!canonicalCodexHome.isAbsolute) {
      throw ArgumentError.value(
        canonicalCodexHome.path,
        'canonicalCodexHome',
        'Canonical Codex home must be absolute.',
      );
    }
    if (cliExecutable != null &&
        (!cliExecutable!.isAbsolute ||
            path.windows.basename(cliExecutable!.path).toLowerCase() !=
                'codex.exe')) {
      throw ArgumentError.value(
        cliExecutable!.path,
        'cliExecutable',
        'Codex CLI must be an absolute codex.exe path.',
      );
    }
    for (final override in configOverrides) {
      if (override.isEmpty ||
          override.length > 2048 ||
          override.contains('\n') ||
          override.contains('\r') ||
          override.contains('\u0000')) {
        throw ArgumentError.value(
          override,
          'configOverrides',
          'Config overrides must be bounded single-line TOML assignments.',
        );
      }
    }
    for (final entry in environmentOverrides.entries) {
      if (!_allowedEnvironmentOverrides.contains(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'environmentOverrides',
          'Unsupported process environment override.',
        );
      }
      _validateManagedHttpUrl(Uri.parse(entry.value));
    }
  }

  final String profileId;
  final Directory canonicalCodexHome;
  final File? cliExecutable;
  final List<String> configOverrides;
  final Map<String, String> environmentOverrides;
}

class CodexAppServerRuntime {
  const CodexAppServerRuntime({
    required this.profileId,
    required this.endpoint,
    required this.processId,
    required this.client,
    required this.canonicalCodexHome,
  });

  final String profileId;
  final Uri endpoint;
  final int processId;
  final CodexAppServerClient client;
  final Directory canonicalCodexHome;
}

class CodexAppServerStartupException implements Exception {
  const CodexAppServerStartupException(
    this.message, {
    this.diagnostics = const <String>[],
  });

  final String message;
  final List<String> diagnostics;

  @override
  String toString() => message;
}

class CodexAppServerSupervisor {
  CodexAppServerSupervisor({
    CodexExecutableResolver? executableResolver,
    CodexAppServerProcessStarter? processStarter,
    CodexProcessBinder? processBinder,
    CodexPortAllocator? portAllocator,
    CodexPortOwnerReader? portOwnerReader,
    this.startupTimeout = const Duration(seconds: 20),
  }) : _executableResolver = executableResolver ?? _resolveCodexExecutable,
       _processStarter = processStarter ?? _startProcess,
       _processBinder =
           processBinder ?? const WindowsPlatformBridge().bindOwnedProcess,
       _portAllocator = portAllocator ?? _allocateLoopbackPort,
       _portOwnerReader = portOwnerReader ?? _readLoopbackPortOwner;

  final CodexExecutableResolver _executableResolver;
  final CodexAppServerProcessStarter _processStarter;
  final CodexProcessBinder _processBinder;
  final CodexPortAllocator _portAllocator;
  final CodexPortOwnerReader _portOwnerReader;
  final Duration startupTimeout;
  final List<String> _diagnostics = <String>[];

  Process? _process;
  CodexAppServerRuntime? _runtime;
  Future<CodexAppServerRuntime>? _starting;

  CodexAppServerRuntime? get runtime => _runtime;
  bool get ownsRuntime => _process != null && _runtime != null;
  List<String> get diagnostics => List<String>.unmodifiable(_diagnostics);

  Future<CodexAppServerRuntime> start(CodexAppServerLaunchOptions options) {
    final existing = _runtime;
    if (existing != null) {
      if (existing.profileId == options.profileId &&
          !existing.client.isClosed) {
        return Future<CodexAppServerRuntime>.value(existing);
      }
      return Future<CodexAppServerRuntime>.error(
        StateError(
          'A different Codex app-server profile is already running. Stop it before switching.',
        ),
      );
    }
    return _starting ??= _start(options).whenComplete(() => _starting = null);
  }

  Future<CodexAppServerRuntime> _start(
    CodexAppServerLaunchOptions options,
  ) async {
    _diagnostics.clear();
    final executable = options.cliExecutable ?? await _executableResolver();
    if (!await executable.exists()) {
      throw CodexAppServerStartupException(
        'Codex CLI executable was not found: ${executable.path}',
      );
    }
    final port = await _portAllocator();
    if (port < 1 || port > 65535) {
      throw CodexAppServerStartupException(
        'Invalid loopback app-server port: $port.',
      );
    }
    final endpoint = Uri.parse('ws://127.0.0.1:$port/');
    final arguments = <String>[
      'app-server',
      '--listen',
      endpoint.toString(),
      for (final override in options.configOverrides) ...<String>[
        '-c',
        override,
      ],
    ];
    final environment = Map<String, String>.from(Platform.environment);
    for (final key in _allowedEnvironmentOverrides) {
      environment.remove(key);
    }
    environment.addAll(options.environmentOverrides);

    final process = await _processStarter(
      executable.path,
      arguments,
      environment,
      executable.parent.path,
    );
    _process = process;
    try {
      await _processBinder(process.pid);
    } on Object catch (error) {
      await _terminate(process);
      _process = null;
      throw CodexAppServerStartupException(
        'The app-server could not be bound to OpenHUB ownership: $error',
      );
    }
    _captureDiagnostics(process.stdout, 'app-server');
    _captureDiagnostics(process.stderr, 'app-server-error');

    final deadline = DateTime.now().add(startupTimeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      if (await _hasExited(process)) {
        _process = null;
        throw CodexAppServerStartupException(
          'Codex app-server exited before becoming ready.',
          diagnostics: diagnostics,
        );
      }
      try {
        final owner = await _portOwnerReader(port);
        if (owner != null && owner != process.pid) {
          throw CodexAppServerStartupException(
            'Loopback app-server port $port is owned by unexpected process $owner.',
          );
        }
        if (owner == process.pid) {
          final client = await CodexAppServerClient.connect(
            endpoint,
            requestTimeout: const Duration(seconds: 2),
          );
          if (!_sameWindowsPath(
            client.initializeInfo.codexHome,
            options.canonicalCodexHome.path,
          )) {
            await client.close();
            throw CodexAppServerStartupException(
              'Codex app-server reported a different Codex home; refusing to split profile history.',
            );
          }
          final runtime = CodexAppServerRuntime(
            profileId: options.profileId,
            endpoint: endpoint,
            processId: process.pid,
            client: client,
            canonicalCodexHome: options.canonicalCodexHome,
          );
          _runtime = runtime;
          return runtime;
        }
      } on CodexAppServerStartupException {
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
    throw CodexAppServerStartupException(
      'Codex app-server did not become ready before the startup timeout.${lastError == null ? '' : ' Last error: $lastError'}',
      diagnostics: diagnostics,
    );
  }

  Future<void> stop() async {
    final runtime = _runtime;
    final process = _process;
    _runtime = null;
    _process = null;
    await runtime?.client.close();
    if (process != null) {
      await _terminate(process);
    }
  }

  void _captureDiagnostics(Stream<List<int>> source, String label) {
    source.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      final sanitized = _sanitizeDiagnostic(line);
      if (sanitized.isEmpty) {
        return;
      }
      _diagnostics.add('[$label] $sanitized');
      if (_diagnostics.length > 60) {
        _diagnostics.removeAt(0);
      }
    });
  }
}

Future<File> _resolveCodexExecutable() async {
  final configured = Platform.environment['CODEX_CLI_PATH'];
  if (configured != null && configured.trim().isNotEmpty) {
    final candidate = File(configured.trim()).absolute;
    if (candidate.path.toLowerCase().endsWith('codex.exe') &&
        await candidate.exists()) {
      return candidate;
    }
  }
  final result = await Process.run('where.exe', const <String>[
    'codex.exe',
  ], runInShell: false);
  if (result.exitCode == 0) {
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final candidate = File(line.trim()).absolute;
      if (candidate.path.toLowerCase().endsWith('codex.exe') &&
          await candidate.exists()) {
        return candidate;
      }
    }
  }
  throw const CodexAppServerStartupException(
    'Codex CLI was not found. Install or update the official Codex app first.',
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

Future<int> _allocateLoopbackPort() async {
  final socket = await ServerSocket.bind(
    InternetAddress.loopbackIPv4,
    0,
    shared: false,
  );
  try {
    return socket.port;
  } finally {
    await socket.close();
  }
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

Future<bool> _hasExited(Process process) async {
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
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // Exact ownership is already proven; there is no broader target to kill.
    }
  }
}

void _validateManagedHttpUrl(Uri uri) {
  final address = InternetAddress.tryParse(uri.host);
  if (uri.scheme != 'http' ||
      !uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      address == null ||
      !address.isLoopback) {
    throw ArgumentError.value(
      uri,
      'environmentOverrides',
      'Managed routes must use credential-free numeric loopback HTTP.',
    );
  }
}

String _sanitizeDiagnostic(String input) {
  return input
      .replaceAll(
        RegExp(r'bearer\s+[^\s,;]+', caseSensitive: false),
        'Bearer [redacted]',
      )
      .replaceAll(RegExp(r'\bsk-[A-Za-z0-9_-]{8,}\b'), 'sk-[redacted]')
      .trim();
}

bool _sameWindowsPath(String left, String right) {
  String normalize(String value) {
    var normalized = value.trim();
    if (normalized.startsWith(r'\\?\')) {
      normalized = normalized.substring(4);
    }
    return path.windows.normalize(path.windows.absolute(normalized));
  }

  return path.windows.equals(normalize(left), normalize(right));
}
