import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/openhub_repository.dart';
import '../api/api_exception.dart';
import 'backup_service.dart';
import 'runtime_config.dart';
import 'windows_platform_bridge.dart';

enum BackendOwnership { attached, owned }

class BackendConnection {
  const BackendConnection({
    required this.ownership,
    required this.processId,
    required this.backup,
  });

  final BackendOwnership ownership;
  final int? processId;
  final BackupResult? backup;
}

class BackendStartupException implements Exception {
  const BackendStartupException(
    this.message, {
    this.diagnostics = const <String>[],
  });

  final String message;
  final List<String> diagnostics;

  @override
  String toString() => message;
}

class BackendSupervisor {
  BackendSupervisor(this._config, this._repository);

  final RuntimeConfig _config;
  final OpenHubRepository _repository;
  final List<String> _diagnostics = <String>[];
  Process? _ownedProcess;
  Future<BackendConnection>? _startup;

  bool get ownsProcess => _ownedProcess != null;
  List<String> get diagnostics => List.unmodifiable(_diagnostics);

  Future<BackendConnection> ensureReady() {
    return _startup ??= _ensureReady().whenComplete(() => _startup = null);
  }

  Future<BackendConnection> _ensureReady() async {
    _diagnostics.clear();
    ApiException? readinessFailure;
    try {
      await _repository.requireReady(
        timeout: const Duration(milliseconds: 900),
      );
      return const BackendConnection(
        ownership: BackendOwnership.attached,
        processId: null,
        backup: null,
      );
    } on ApiException catch (error) {
      readinessFailure = error;
      // A failed bounded readiness probe is the expected path when no local
      // backend is running. Startup below remains preservation-gated.
    }

    if (_config.attachOnly || _config.backendExecutable == null) {
      throw const BackendStartupException(
        'No compatible local backend is ready. Place the pinned sidecar beside the app or start it explicitly.',
      );
    }
    if (_config.endpoint.host != '127.0.0.1') {
      throw const BackendStartupException(
        'Managed startup requires the endpoint host to be exactly 127.0.0.1.',
      );
    }
    if (!await _portIsAvailable()) {
      final attached = await _waitForCompatibleAttachedBackend();
      if (attached) {
        return const BackendConnection(
          ownership: BackendOwnership.attached,
          processId: null,
          backup: null,
        );
      }
      final actionableDetail =
          readinessFailure.code == 'backend_protocol_mismatch'
          ? ' ${readinessFailure.message}'
          : '';
      throw BackendStartupException(
        'Loopback port ${_config.port} is occupied by a service that did not identify as compatible openhub ${OpenHubRepository.compatibleBackendVersion}.$actionableDetail No backup or child process was started.',
      );
    }
    final executable = _config.backendExecutable!;
    if (!await executable.exists()) {
      throw BackendStartupException(
        'Pinned backend sidecar is missing: ${executable.path}',
      );
    }

    const platformBridge = WindowsPlatformBridge();
    final backupService = BackupService(
      (database) => _runIntegrityProbe(executable, database),
      hardenPrivatePath: platformBridge.hardenPrivatePath,
    );
    final backup = await backupService.createVerifiedBackup(
      dataDirectory: _config.dataDirectory,
      backupRoot: _config.backupDirectory,
    );
    final encryptionKey = File(
      '${_config.dataDirectory.path}${Platform.pathSeparator}encryption.key',
    );
    if (await encryptionKey.exists()) {
      try {
        await platformBridge.hardenPrivatePath(encryptionKey.path);
      } on Object {
        throw const BackendStartupException(
          'The encryption key could not be restricted to the current user, SYSTEM, and local administrators. No backend process was started.',
        );
      }
    }

    final process = await Process.start(
      executable.path,
      <String>['--host', '127.0.0.1', '--port', _config.port.toString()],
      environment: <String, String>{
        ...Platform.environment,
        'OPENHUB_DATA_DIR': _config.dataDirectory.path,
        'PORT': _config.port.toString(),
      },
      workingDirectory: executable.parent.path,
      mode: ProcessStartMode.normal,
    );
    try {
      await platformBridge.bindOwnedProcess(process.pid);
    } on Object {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 4));
      } on TimeoutException {
        process.kill();
      }
      throw const BackendStartupException(
        'The pinned backend could not be bound to the native app lifetime. The child was stopped.',
      );
    }
    _ownedProcess = process;
    // Backend stdout can contain one-time bootstrap material. Drain it so the
    // child cannot block, but never retain or surface it in the native client.
    unawaited(process.stdout.drain<void>());
    _captureDiagnostics(process.stderr, 'backend-error');

    final deadline = DateTime.now().add(_config.startupTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _hasExited(process)) {
        _ownedProcess = null;
        throw BackendStartupException(
          'The pinned backend exited before becoming ready.',
          diagnostics: diagnostics,
        );
      }
      try {
        await _repository.requireReady(
          timeout: const Duration(milliseconds: 900),
        );
        return BackendConnection(
          ownership: BackendOwnership.owned,
          processId: process.pid,
          backup: backup,
        );
      } on ApiException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    await stopOwned();
    throw BackendStartupException(
      'The pinned backend did not become ready within ${_config.startupTimeout.inSeconds} seconds.',
      diagnostics: diagnostics,
    );
  }

  Future<bool> _portIsAvailable() async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _config.port,
        shared: false,
      );
      return true;
    } on SocketException {
      return false;
    } finally {
      await socket?.close();
    }
  }

  Future<bool> _waitForCompatibleAttachedBackend() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      try {
        await _repository.requireReady(
          timeout: const Duration(milliseconds: 500),
        );
        return true;
      } on ApiException {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    return false;
  }

  Future<void> _runIntegrityProbe(File executable, File database) async {
    final result = await Process.run(
      executable.path,
      <String>['data', 'integrity-check', '--database', database.path],
      workingDirectory: executable.parent.path,
      environment: Platform.environment,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(seconds: 20));
    if (result.exitCode != 0 ||
        result.stdout.toString().trim() != 'sqlite_integrity=ok') {
      throw BackupException(
        'The copied SQLite database failed the sidecar integrity check.',
        backupPath: database.parent.path,
      );
    }
  }

  void _captureDiagnostics(Stream<List<int>> stream, String source) {
    stream.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      final sanitized = _sanitizeDiagnostic(line);
      if (sanitized.isEmpty) {
        return;
      }
      _diagnostics.add('[$source] $sanitized');
      if (_diagnostics.length > 80) {
        _diagnostics.removeAt(0);
      }
    });
  }

  String _sanitizeDiagnostic(String input) {
    return sanitizeBackendDiagnostic(input);
  }

  Future<bool> _hasExited(Process process) async {
    return Future.any<bool>(<Future<bool>>[
      process.exitCode.then((_) => true),
      Future<bool>.delayed(const Duration(milliseconds: 1), () => false),
    ]);
  }

  Future<void> stopOwned() async {
    final process = _ownedProcess;
    if (process == null) {
      return;
    }
    _ownedProcess = null;
    try {
      await _repository.startDrain();
    } on Object {
      // The process may have already failed; exact ownership still makes the
      // following termination safe.
    }
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      process.kill();
    }
  }
}

String sanitizeBackendDiagnostic(String input) {
  return input
      .replaceAll(
        RegExp(r'bearer\s+[^\s,;]+', caseSensitive: false),
        'Bearer [redacted]',
      )
      .replaceAll(
        RegExp(
          r'(access|refresh|id)[_-]?token["\s:=]+[^\s,;]+',
          caseSensitive: false,
        ),
        r'$1_token=[redacted]',
      )
      .replaceAll(
        RegExp(
          r'(bootstrap[\s_-]*token|api[\s_-]*key|password|secret|device[\s_-]*code|user[\s_-]*code)["\s:=]+[^\s,;]+',
          caseSensitive: false,
        ),
        r'$1=[redacted]',
      )
      .replaceAll(RegExp(r'\bsk-[A-Za-z0-9_-]{8,}\b'), 'sk-[redacted]')
      .replaceAll(
        RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
        '[redacted-jwt]',
      )
      .trim();
}
