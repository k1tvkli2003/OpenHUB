import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/runtime/codex_installation_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'discovers Desktop, CLI, capabilities, and one canonical home',
    () async {
      final root = Directory.systemTemp.createTempSync('openhub-discovery-');
      addTearDown(() => root.deleteSync(recursive: true));
      final desktop = File('${root.path}${Platform.pathSeparator}ChatGPT.exe')
        ..writeAsBytesSync(const <int>[]);
      final cli = File('${root.path}${Platform.pathSeparator}codex.exe')
        ..writeAsBytesSync(const <int>[]);
      final asar = File('${root.path}${Platform.pathSeparator}app.asar')
        ..writeAsStringSync(
          'CODEX_APP_SERVER_WS_URL '
          'CODEX_APP_SERVER_OPENAI_BASE_URL '
          'CODEX_APP_SERVER_CHATGPT_BASE_URL',
        );
      final canonicalHome = Directory(
        '${root.path}${Platform.pathSeparator}.codex',
      );
      final discovery = WindowsCodexInstallationDiscovery(
        environment: <String, String>{'CODEX_HOME': canonicalHome.path},
        cliResolver: () async => cli,
        powerShellRunner: (_) async => ProcessResult(
          1,
          0,
          jsonEncode(<String, String>{
            'packageVersion': '26.820.60940.0',
            'executablePath': desktop.path,
            'applicationId': 'App',
            'asarPath': asar.path,
          }),
          '',
        ),
      );

      final result = await discovery.discover();
      expect(result.desktopVersion, '26.820.60940.0');
      expect(result.desktopExecutable.path, desktop.absolute.path);
      expect(result.cliExecutable.path, cli.absolute.path);
      expect(result.canonicalCodexHome.path, canonicalHome.absolute.path);
      expect(result.supportsAppServerWebSocket, isTrue);
      expect(result.supportsManagedOpenAiRoutes, isTrue);
      expect(result.supportsManagedProfiles, isTrue);
    },
  );

  test('rejects a non-Codex CLI executable', () async {
    final root = Directory.systemTemp.createTempSync('openhub-discovery-bad-');
    addTearDown(() => root.deleteSync(recursive: true));
    final desktop = File('${root.path}${Platform.pathSeparator}ChatGPT.exe')
      ..writeAsBytesSync(const <int>[]);
    final cli = File('${root.path}${Platform.pathSeparator}other.exe')
      ..writeAsBytesSync(const <int>[]);
    final asar = File('${root.path}${Platform.pathSeparator}app.asar')
      ..writeAsStringSync('CODEX_APP_SERVER_WS_URL');
    final discovery = WindowsCodexInstallationDiscovery(
      environment: <String, String>{'USERPROFILE': root.path},
      cliResolver: () async => cli,
      powerShellRunner: (_) async => ProcessResult(
        1,
        0,
        jsonEncode(<String, String>{
          'packageVersion': '1',
          'executablePath': desktop.path,
          'applicationId': 'App',
          'asarPath': asar.path,
        }),
        '',
      ),
    );

    expect(
      discovery.discover(),
      throwsA(isA<CodexInstallationDiscoveryException>()),
    );
  });
}
