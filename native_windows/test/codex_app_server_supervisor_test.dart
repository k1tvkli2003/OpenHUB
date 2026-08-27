import 'dart:convert';
import 'dart:io';

import 'package:openhub_windows/src/core/runtime/codex_app_server_supervisor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'supervisor owns, verifies, reuses, and stops one profile runtime',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((raw) {
          final message = (jsonDecode(raw as String) as Map)
              .cast<String, Object?>();
          final id = message['id'];
          if (id == null) {
            return;
          }
          final result = switch (message['method']) {
            'initialize' => <String, Object?>{
              'codexHome': r'C:\Users\test\.codex',
              'platformFamily': 'windows',
              'platformOs': 'windows',
              'userAgent': 'codex-cli/test',
            },
            'thread/list' => <String, Object?>{
              'data': const <Object?>[],
              'nextCursor': null,
            },
            _ => <String, Object?>{},
          };
          socket.add(jsonEncode(<String, Object?>{'id': id, 'result': result}));
        });
      });

      final root = Directory.systemTemp.createTempSync('openhub-supervisor-');
      addTearDown(() => root.deleteSync(recursive: true));
      final whereFlutter = await Process.run('where.exe', const <String>[
        'flutter.bat',
      ], runInShell: false);
      final flutterExecutable = const LineSplitter()
          .convert(whereFlutter.stdout.toString())
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty);
      final dartExecutable = File(
        flutterExecutable,
      ).parent.uri.resolve('cache/dart-sdk/bin/dart.exe').toFilePath();
      final sleeper = File('${root.path}${Platform.pathSeparator}sleeper.dart')
        ..writeAsStringSync('''
import 'dart:async';
Future<void> main() => Future<void>.delayed(const Duration(minutes: 2));
''');
      Process? ownedProcess;
      Map<String, String>? launchedEnvironment;
      List<String>? launchedArguments;
      final supervisor = CodexAppServerSupervisor(
        executableResolver: () async => File(dartExecutable),
        portAllocator: () async => server.port,
        processStarter:
            (executable, arguments, environment, workingDirectory) async {
              launchedArguments = List<String>.from(arguments);
              launchedEnvironment = Map<String, String>.from(environment);
              ownedProcess = await Process.start(dartExecutable, <String>[
                sleeper.path,
              ], mode: ProcessStartMode.normal);
              return ownedProcess!;
            },
        processBinder: (_) async {},
        portOwnerReader: (_) async => ownedProcess?.pid,
        startupTimeout: const Duration(seconds: 3),
      );
      addTearDown(supervisor.stop);

      final options = CodexAppServerLaunchOptions(
        profileId: 'openai-pool',
        canonicalCodexHome: Directory(r'C:\Users\test\.codex'),
        configOverrides: const <String>['model="gpt-5.6-sol"'],
        environmentOverrides: const <String, String>{
          'CODEX_APP_SERVER_OPENAI_BASE_URL':
              'http://127.0.0.1:2455/backend-api/codex-managed/v1',
        },
      );
      final runtime = await supervisor.start(options);
      expect(runtime.profileId, 'openai-pool');
      expect(runtime.processId, ownedProcess?.pid);
      expect(runtime.client.initializeInfo.platformOs, 'windows');
      expect(supervisor.ownsRuntime, isTrue);
      expect(await supervisor.start(options), same(runtime));
      expect(
        launchedArguments,
        containsAllInOrder(<String>[
          'app-server',
          '--listen',
          'ws://127.0.0.1:${server.port}/',
          '-c',
          'model="gpt-5.6-sol"',
        ]),
      );
      expect(
        launchedEnvironment?['CODEX_APP_SERVER_OPENAI_BASE_URL'],
        'http://127.0.0.1:2455/backend-api/codex-managed/v1',
      );
      expect(
        launchedEnvironment?['CODEX_HOME'],
        Platform.environment['CODEX_HOME'],
      );

      await supervisor.stop();
      expect(supervisor.ownsRuntime, isFalse);
      expect(await ownedProcess?.exitCode, isNotNull);
    },
  );

  test('launch options reject remote routes and unknown environment keys', () {
    expect(
      () => CodexAppServerLaunchOptions(
        profileId: 'bad',
        canonicalCodexHome: Directory(r'C:\Users\test\.codex'),
        environmentOverrides: const <String, String>{
          'CODEX_APP_SERVER_OPENAI_BASE_URL': 'https://example.com/v1',
        },
      ),
      throwsArgumentError,
    );
    expect(
      () => CodexAppServerLaunchOptions(
        profileId: 'bad',
        canonicalCodexHome: Directory(r'C:\Users\test\.codex'),
        environmentOverrides: const <String, String>{'CODEX_HOME': r'C:\other'},
      ),
      throwsArgumentError,
    );
  });
}
