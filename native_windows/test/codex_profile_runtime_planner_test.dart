import 'dart:io';

import 'package:openhub_windows/src/core/runtime/codex_installation_discovery.dart';
import 'package:openhub_windows/src/core/runtime/codex_profile_runtime_planner.dart';
import 'package:openhub_windows/src/models/codex_integration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late Directory assets;
  late CodexInstallation installation;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('openhub-profile-plan-');
    assets = Directory('${temporary.path}\\assets');
    await Directory('${assets.path}\\ox').create(recursive: true);
    await File('${assets.path}\\ox\\opencode-ox.json').writeAsString('{}');
    await File(
      '${assets.path}\\ox\\openhub-ox-adapter.mjs',
    ).writeAsString('// fixture');
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

  test(
    'OpenAI Pool uses managed routes and the discovered shared home',
    () async {
      final plan = await CodexProfileRuntimePlanner(assetRoot: assets).build(
        profile: _openAiProfile,
        installation: installation,
        managedOpenAiBaseUrl: Uri.parse(
          'http://127.0.0.1:2455/backend-api/codex-managed/v1',
        ),
      );

      expect(plan.appServerOptions.canonicalCodexHome.path, endsWith('.codex'));
      expect(plan.appServerOptions.cliExecutable?.path, endsWith('codex.exe'));
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
      expect(
        plan.appServerOptions.configOverrides,
        isNot(contains('model_catalog_json')),
      );
    },
  );

  test(
    'Ox resolves only packaged assets and owns a complete provider overlay',
    () async {
      final plan = await CodexProfileRuntimePlanner(assetRoot: assets).build(
        profile: _oxProfile,
        installation: installation,
        managedOpenAiBaseUrl: Uri.parse(
          'http://127.0.0.1:2455/backend-api/codex-managed/v1',
        ),
      );

      expect(plan.bridgeScript?.path, endsWith('openhub-ox-adapter.mjs'));
      expect(plan.modelCatalog?.path, endsWith('opencode-ox.json'));
      expect(
        plan.appServerOptions.configOverrides,
        containsAll(<String>[
          'model="x-preview-f-free"',
          'model_provider="opencode_zen"',
          'model_providers.opencode_zen.wire_api="responses"',
          'model_context_window=1000000',
        ]),
      );
      expect(
        plan.appServerOptions.configOverrides.singleWhere(
          (entry) => entry.startsWith('model_catalog_json='),
        ),
        isNot(contains('C:\\Users\\K1')),
      );
    },
  );
}

const _openAiProfile = CodexProfileDefinition(
  id: 'openai-pool',
  label: 'OpenAI Pool',
  kind: 'openai_pool',
  modelProvider: 'openai',
  model: 'gpt-5.6-sol',
  wireApi: 'responses',
  catalogSource: 'live_managed',
  accountRouting: 'automatic',
  builtin: true,
);

const _oxProfile = CodexProfileDefinition(
  id: 'ox',
  label: 'Ox',
  kind: 'ox',
  modelProvider: 'opencode_zen',
  model: 'x-preview-f-free',
  wireApi: 'responses',
  baseUrl: 'http://127.0.0.1:17891/v1',
  catalogSource: 'bundled',
  catalogUri: 'asset://ox/opencode-ox.json',
  bridgeUri: 'asset://ox/openhub-ox-adapter.mjs',
  contextWindow: 1000000,
  accountRouting: 'none',
  builtin: true,
);
