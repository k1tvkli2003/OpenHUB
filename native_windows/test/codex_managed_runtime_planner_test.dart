import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openhub_windows/src/core/runtime/codex_installation_discovery.dart';
import 'package:openhub_windows/src/core/runtime/codex_managed_runtime_planner.dart';

void main() {
  late Directory temporary;
  late CodexInstallation installation;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('openhub-runtime-plan-');
    final desktop = File('${temporary.path}\\ChatGPT.exe');
    final asar = File('${temporary.path}\\app.asar');
    final cli = File('${temporary.path}\\codex.exe');
    await Future.wait(<Future<File>>[
      desktop.writeAsBytes(const <int>[1]),
      asar.writeAsBytes(const <int>[1]),
      cli.writeAsBytes(const <int>[1]),
    ]);
    installation = CodexInstallation(
      desktopVersion: 'fixture',
      desktopExecutable: desktop,
      desktopApplicationId: 'App',
      asarFile: asar,
      cliExecutable: cli,
      canonicalCodexHome: Directory('${temporary.path}\\.codex'),
      supportsAppServerWebSocket: true,
      supportsManagedOpenAiRoutes: true,
    );
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test('uses the managed route without overriding Codex model selection', () {
    final plan = const CodexManagedRuntimePlanner().build(
      installation: installation,
      managedOpenAiBaseUrl: Uri.parse(
        'http://127.0.0.1:2455/backend-api/codex-managed/v1',
      ),
    );

    expect(plan.appServerOptions.profileId, 'openhub-openai-router');
    expect(plan.appServerOptions.canonicalCodexHome.path, endsWith('.codex'));
    expect(plan.appServerOptions.cliExecutable?.path, endsWith('codex.exe'));
    expect(plan.appServerOptions.configOverrides, isEmpty);
    expect(
      plan.appServerOptions.environmentOverrides,
      containsPair(
        'CODEX_APP_SERVER_OPENAI_BASE_URL',
        'http://127.0.0.1:2455/backend-api/codex-managed/v1',
      ),
    );
    expect(
      plan.appServerOptions.environmentOverrides,
      containsPair(
        'CODEX_APP_SERVER_CHATGPT_BASE_URL',
        'http://127.0.0.1:2455/backend-api/codex-managed',
      ),
    );
  });
}
