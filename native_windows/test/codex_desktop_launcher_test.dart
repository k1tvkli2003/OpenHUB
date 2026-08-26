import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/runtime/codex_desktop_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'running detection is scoped to the installed Codex AppX root',
    () async {
      String? captured;
      final launcher = WindowsCodexDesktopLauncher(
        powerShellRunner: (script) async {
          captured = script;
          return ProcessResult(1, 0, '1\n', '');
        },
      );

      expect(await launcher.isRunning(), isTrue);
      expect(captured, contains('Get-AppxPackage -Name OpenAI.Codex'));
      expect(captured, contains('package.InstallLocation'));
      expect(captured, contains('Get-Process -Name ChatGPT,Codex'));
      expect(captured, isNot(contains('MainWindowHandle')));
      expect(captured, contains(r'StartsWith($packagePrefix'));
    },
  );

  test('running detection fails safely when PowerShell inspection fails', () {
    final launcher = WindowsCodexDesktopLauncher(
      powerShellRunner: (_) async => ProcessResult(1, 5, '', 'denied'),
    );

    expect(launcher.isRunning(), throwsA(isA<StateError>()));
  });

  test('focus targets only the installed Codex AppX window', () async {
    String? captured;
    final launcher = WindowsCodexDesktopLauncher(
      powerShellRunner: (script) async {
        captured = script;
        return ProcessResult(1, 0, '1\n', '');
      },
    );

    expect(await launcher.focusRunning(), isTrue);
    expect(captured, contains('Get-AppxPackage -Name OpenAI.Codex'));
    expect(captured, contains(r'StartsWith($packagePrefix'));
    expect(captured, contains(r'AppActivate($process.Id)'));
  });

  test(
    'managed launch injects ChatGPT and OpenAI routes into one new process',
    () async {
      final root = Directory.systemTemp.createTempSync('openhub-launcher-');
      addTearDown(() => root.deleteSync(recursive: true));
      final executable = File('${root.path}\\ChatGPT.exe')
        ..writeAsBytesSync(const <int>[]);
      final asar = File('${root.path}\\app.asar')
        ..writeAsStringSync(
          'CODEX_APP_SERVER_CHATGPT_BASE_URL '
          'CODEX_APP_SERVER_OPENAI_BASE_URL '
          'CODEX_APP_SERVER_WS_URL',
        );
      Map<String, String>? startedEnvironment;
      var processStarted = false;
      final launcher = WindowsCodexDesktopLauncher(
        powerShellRunner: (script) async {
          if (script.contains('ConvertTo-Json -Compress')) {
            return ProcessResult(
              1,
              0,
              jsonEncode(<String, String>{
                'packageVersion': '26.803.5235.0',
                'executablePath': executable.path,
                'applicationId': 'App',
                'asarPath': asar.path,
              }),
              '',
            );
          }
          if (script.contains(r'AppActivate($process.Id)')) {
            return ProcessResult(1, 0, processStarted ? '1\n' : '0\n', '');
          }
          if (script.contains('Get-CimInstance Win32_Process')) {
            return ProcessResult(1, 0, processStarted ? '1\n' : '0\n', '');
          }
          return ProcessResult(1, 0, '0\n', '');
        },
        processStarter:
            (executable, arguments, environment, workingDirectory) async {
              startedEnvironment = Map<String, String>.from(environment);
              processStarted = true;
              return 4242;
            },
      );

      final result = await launcher.launch(
        managedBaseUrl: Uri.parse(
          'http://127.0.0.1:2455/backend-api/codex-managed/v1',
        ),
      );

      expect(result.launched, isTrue);
      expect(result.managed, isTrue);
      expect(
        startedEnvironment?['CODEX_APP_SERVER_OPENAI_BASE_URL'],
        'http://127.0.0.1:2455/backend-api/codex-managed/v1',
      );
      expect(
        startedEnvironment?['CODEX_APP_SERVER_CHATGPT_BASE_URL'],
        'http://127.0.0.1:2455/backend-api/codex-managed',
      );
      expect(startedEnvironment, isNot(contains('CODEX_HOME')));
      expect(startedEnvironment, isNot(contains('CODEX_SQLITE_HOME')));
    },
  );

  test('managed launch fails when the app-server drops both overrides', () {
    final root = Directory.systemTemp.createTempSync(
      'openhub-launcher-unmanaged-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final executable = File('${root.path}\\ChatGPT.exe')
      ..writeAsBytesSync(const <int>[]);
    final asar = File('${root.path}\\app.asar')
      ..writeAsStringSync(
        'CODEX_APP_SERVER_CHATGPT_BASE_URL '
        'CODEX_APP_SERVER_OPENAI_BASE_URL '
        'CODEX_APP_SERVER_WS_URL',
      );
    var processStarted = false;
    final launcher = WindowsCodexDesktopLauncher(
      launchConfirmationTimeout: const Duration(milliseconds: 40),
      powerShellRunner: (script) async {
        if (script.contains('ConvertTo-Json -Compress')) {
          return ProcessResult(
            1,
            0,
            jsonEncode(<String, String>{
              'packageVersion': '26.803.5235.0',
              'executablePath': executable.path,
              'applicationId': 'App',
              'asarPath': asar.path,
            }),
            '',
          );
        }
        if (script.contains(r'AppActivate($process.Id)')) {
          return ProcessResult(1, 0, processStarted ? '1\n' : '0\n', '');
        }
        if (script.contains('Get-CimInstance Win32_Process')) {
          return ProcessResult(1, 0, '0\n', '');
        }
        return ProcessResult(1, 0, '0\n', '');
      },
      processStarter:
          (executable, arguments, environment, workingDirectory) async {
            processStarted = true;
            return 4242;
          },
    );

    expect(
      launcher.launch(
        managedBaseUrl: Uri.parse(
          'http://127.0.0.1:2455/backend-api/codex-managed/v1',
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('managed runtime could not be verified'),
        ),
      ),
    );
  });

  test(
    'managed WebSocket launch injects the supervised app-server URL',
    () async {
      final root = Directory.systemTemp.createTempSync('openhub-ws-launcher-');
      addTearDown(() => root.deleteSync(recursive: true));
      final executable = File('${root.path}\\ChatGPT.exe')
        ..writeAsBytesSync(const <int>[]);
      final asar = File('${root.path}\\app.asar')
        ..writeAsStringSync(
          'CODEX_APP_SERVER_CHATGPT_BASE_URL '
          'CODEX_APP_SERVER_OPENAI_BASE_URL '
          'CODEX_APP_SERVER_WS_URL',
        );
      Map<String, String>? startedEnvironment;
      var processStarted = false;
      final launcher = WindowsCodexDesktopLauncher(
        powerShellRunner: (script) async {
          if (script.contains('ConvertTo-Json -Compress')) {
            return ProcessResult(
              1,
              0,
              jsonEncode(<String, String>{
                'packageVersion': '26.820.60940.0',
                'executablePath': executable.path,
                'applicationId': 'App',
                'asarPath': asar.path,
              }),
              '',
            );
          }
          if (script.contains(r'AppActivate($process.Id)')) {
            return ProcessResult(1, 0, processStarted ? '1\n' : '0\n', '');
          }
          return ProcessResult(1, 0, '0\n', '');
        },
        processStarter:
            (executable, arguments, environment, workingDirectory) async {
              startedEnvironment = Map<String, String>.from(environment);
              processStarted = true;
              return 4242;
            },
      );

      final result = await launcher.launch(
        appServerWebSocketUrl: Uri.parse('ws://127.0.0.1:45911/'),
      );

      expect(result.launched, isTrue);
      expect(result.managed, isTrue);
      expect(
        startedEnvironment?['CODEX_APP_SERVER_WS_URL'],
        'ws://127.0.0.1:45911/',
      );
    },
  );
}
