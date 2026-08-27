import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class WindowsPlatformBridge {
  const WindowsPlatformBridge();

  static const MethodChannel _channel = MethodChannel('openhub/native');

  void installCloseHandler(Future<void> Function() onCloseRequested) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'requestClose') {
        throw MissingPluginException('Unknown native callback: ${call.method}');
      }
      await onCloseRequested();
      return true;
    });
  }

  void clearCloseHandler() {
    _channel.setMethodCallHandler(null);
  }

  Future<void> allowWindowClose() async {
    final allowed = await _channel.invokeMethod<bool>('allowWindowClose');
    if (allowed != true) {
      throw PlatformException(
        code: 'close_failed',
        message: 'Windows did not confirm the native close handshake.',
      );
    }
  }

  Future<void> bindOwnedProcess(int processId) async {
    if (processId <= 0) {
      throw ArgumentError.value(processId, 'processId', 'Must be positive.');
    }
    final bound = await _channel.invokeMethod<bool>(
      'bindOwnedProcess',
      processId,
    );
    if (bound != true) {
      throw PlatformException(
        code: 'job_assignment_failed',
        message: 'Windows did not bind the sidecar to the app lifetime.',
      );
    }
  }

  Future<int> launchManagedCodex({
    required String executablePath,
    required String workingDirectory,
    Uri? chatGptBaseUrl,
    Uri? openAiBaseUrl,
    Uri? appServerWebSocketUrl,
  }) async {
    final normalizedExecutable = path.windows.normalize(executablePath);
    final normalizedWorkingDirectory = path.windows.normalize(workingDirectory);
    if (!path.windows.isAbsolute(normalizedExecutable) ||
        path.windows.basename(normalizedExecutable).toLowerCase() !=
            'chatgpt.exe' ||
        !path.windows.equals(
          path.windows.dirname(normalizedExecutable),
          normalizedWorkingDirectory,
        )) {
      throw ArgumentError.value(
        executablePath,
        'executablePath',
        'Expected the exact installed ChatGPT.exe and its working directory.',
      );
    }
    final hasRoutes = chatGptBaseUrl != null || openAiBaseUrl != null;
    if (hasRoutes && (chatGptBaseUrl == null || openAiBaseUrl == null)) {
      throw ArgumentError(
        'ChatGPT and OpenAI managed routes must be supplied together.',
      );
    }
    if (chatGptBaseUrl != null && openAiBaseUrl != null) {
      _validateManagedLoopbackUrl(
        chatGptBaseUrl,
        expectedPath: '/backend-api/codex-managed',
      );
      _validateManagedLoopbackUrl(
        openAiBaseUrl,
        expectedPath: '/backend-api/codex-managed/v1',
      );
    }
    if (appServerWebSocketUrl != null) {
      _validateManagedWebSocketUrl(appServerWebSocketUrl);
    }
    if (!hasRoutes && appServerWebSocketUrl == null) {
      throw ArgumentError(
        'Managed Codex launch requires a route or app-server WebSocket.',
      );
    }
    final arguments = <String, String>{
      'executablePath': normalizedExecutable,
      'workingDirectory': normalizedWorkingDirectory,
      if (chatGptBaseUrl != null) 'chatGptBaseUrl': chatGptBaseUrl.toString(),
      if (openAiBaseUrl != null) 'openAiBaseUrl': openAiBaseUrl.toString(),
      if (appServerWebSocketUrl != null)
        'appServerWebSocketUrl': appServerWebSocketUrl.toString(),
    };
    final processId = await _channel.invokeMethod<int>(
      'launchManagedCodex',
      arguments,
    );
    if (processId == null || processId <= 0) {
      throw PlatformException(
        code: 'managed_launch_failed',
        message: 'Windows did not return the managed Codex process ID.',
      );
    }
    return processId;
  }

  Future<void> openExternalUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        rawUrl,
        'rawUrl',
        'Expected a safe HTTP(S) URL.',
      );
    }
    final opened = await _channel.invokeMethod<bool>(
      'openExternalUrl',
      uri.toString(),
    );
    if (opened != true) {
      throw PlatformException(
        code: 'open_failed',
        message: 'Windows did not confirm opening the URL.',
      );
    }
  }

  Future<void> openCodexThread(String threadId) async {
    final normalized = threadId.trim().toLowerCase();
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(normalized)) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'Expected a canonical Codex thread UUID.',
      );
    }
    final opened = await _channel.invokeMethod<bool>(
      'openCodexThread',
      normalized,
    );
    if (opened != true) {
      throw PlatformException(
        code: 'open_failed',
        message: 'Windows did not confirm opening the Codex task.',
      );
    }
  }

  Future<void> openHermesSession(String sessionId, {String? workingDirectory}) {
    return _openRuntimeSession(
      runtime: 'hermes',
      sessionId: sessionId,
      workingDirectory: workingDirectory,
    );
  }

  Future<void> openOpenCodeSession(
    String sessionId, {
    String? workingDirectory,
  }) {
    return _openRuntimeSession(
      runtime: 'opencode',
      sessionId: sessionId,
      workingDirectory: workingDirectory,
    );
  }

  Future<void> _openRuntimeSession({
    required String runtime,
    required String sessionId,
    String? workingDirectory,
  }) async {
    final normalizedId = sessionId.trim();
    if (!RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$',
    ).hasMatch(normalizedId)) {
      throw ArgumentError.value(
        sessionId,
        'sessionId',
        'Expected a bounded native runtime session identifier.',
      );
    }
    final rawWorkingDirectory = workingDirectory?.trim();
    final normalizedWorkingDirectory =
        rawWorkingDirectory == null || rawWorkingDirectory.isEmpty
        ? null
        : path.windows.normalize(rawWorkingDirectory);
    if (normalizedWorkingDirectory != null &&
        !path.windows.isAbsolute(normalizedWorkingDirectory)) {
      throw ArgumentError.value(
        workingDirectory,
        'workingDirectory',
        'Expected an absolute Windows working directory.',
      );
    }
    final opened = await _channel.invokeMethod<bool>('openRuntimeSession', {
      'runtime': runtime,
      'sessionId': normalizedId,
      'workingDirectory': ?normalizedWorkingDirectory,
    });
    if (opened != true) {
      throw PlatformException(
        code: 'open_failed',
        message: 'Windows did not confirm opening the $runtime task.',
      );
    }
  }

  Future<void> hardenPrivatePath(String rawPath) async {
    final normalized = path.normalize(path.absolute(rawPath));
    if (!path.isAbsolute(normalized) ||
        path.equals(path.dirname(normalized), normalized)) {
      throw ArgumentError.value(
        rawPath,
        'rawPath',
        'Expected a non-root absolute path.',
      );
    }
    final type = await FileSystemEntity.type(normalized, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.directory) {
      throw ArgumentError.value(
        rawPath,
        'rawPath',
        'Private ACL target must be an existing file or directory.',
      );
    }
    final hardened = await _channel.invokeMethod<bool>(
      'hardenPrivatePath',
      normalized,
    );
    if (hardened != true) {
      throw PlatformException(
        code: 'acl_failed',
        message: 'Windows did not confirm private ACL hardening.',
      );
    }
  }
}

void _validateManagedWebSocketUrl(Uri uri) {
  final address = InternetAddress.tryParse(uri.host);
  if (uri.scheme != 'ws' ||
      !uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      address == null ||
      !address.isLoopback ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw ArgumentError.value(
      uri,
      'appServerWebSocketUrl',
      'Expected a credential-free numeric loopback WebSocket URL.',
    );
  }
}

void _validateManagedLoopbackUrl(Uri uri, {required String expectedPath}) {
  final address = InternetAddress.tryParse(uri.host);
  if (uri.scheme != 'http' ||
      !uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      address == null ||
      !address.isLoopback ||
      uri.path != expectedPath) {
    throw ArgumentError.value(
      uri,
      'uri',
      'Expected the fixed numeric loopback managed Codex URL.',
    );
  }
}
