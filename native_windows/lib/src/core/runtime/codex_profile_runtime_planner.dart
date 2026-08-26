import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../models/codex_integration.dart';
import 'codex_app_server_supervisor.dart';
import 'codex_installation_discovery.dart';

class CodexProfileRuntimePlan {
  const CodexProfileRuntimePlan({
    required this.profile,
    required this.appServerOptions,
    this.bridgeScript,
    this.modelCatalog,
  });

  final CodexProfileDefinition profile;
  final CodexAppServerLaunchOptions appServerOptions;
  final File? bridgeScript;
  final File? modelCatalog;
}

class CodexProfileRuntimePlanner {
  const CodexProfileRuntimePlanner({this.assetRoot});

  /// Explicit in tests and developer runs. Packaged builds resolve against
  /// Flutter's Windows asset directory next to the executable.
  final Directory? assetRoot;

  Future<CodexProfileRuntimePlan> build({
    required CodexProfileDefinition profile,
    required CodexInstallation installation,
    required Uri managedOpenAiBaseUrl,
  }) async {
    final config = <String>[
      'model=${_tomlString(profile.model)}',
      'model_provider=${_tomlString(profile.modelProvider)}',
    ];
    final environment = <String, String>{};
    File? catalog;
    File? bridge;

    if (profile.kind == 'openai_pool') {
      _validateManagedOpenAiBaseUrl(managedOpenAiBaseUrl);
      environment['CODEX_APP_SERVER_OPENAI_BASE_URL'] = managedOpenAiBaseUrl
          .toString();
      environment['CODEX_APP_SERVER_CHATGPT_BASE_URL'] = _chatGptBaseUrl(
        managedOpenAiBaseUrl,
      ).toString();
    } else {
      final baseUrl = Uri.tryParse(profile.baseUrl ?? '');
      if (baseUrl == null || !baseUrl.hasAuthority) {
        throw StateError(
          'Profile ${profile.id} does not define a valid provider endpoint.',
        );
      }
      final providerKey = 'model_providers.${profile.modelProvider}';
      config.addAll(<String>[
        '$providerKey.name=${_tomlString(profile.label)}',
        '$providerKey.base_url=${_tomlString(baseUrl.toString())}',
        '$providerKey.wire_api=${_tomlString(profile.wireApi)}',
      ]);
      if (profile.kind == 'ox') {
        config.addAll(<String>[
          '$providerKey.requires_openai_auth=true',
          '$providerKey.request_max_retries=100',
          '$providerKey.stream_max_retries=100',
          '$providerKey.stream_idle_timeout_ms=600000',
          '$providerKey.supports_websockets=false',
          '$providerKey.supports_standalone_web_search=true',
          'features.standalone_web_search=true',
          'web_search="live"',
        ]);
      }
    }

    if (profile.contextWindow case final contextWindow?) {
      config.add('model_context_window=$contextWindow');
    }
    if (profile.catalogUri case final catalogUri?) {
      catalog = await _resolveAsset(catalogUri);
      config.add('model_catalog_json=${_tomlString(catalog.path)}');
    }
    if (profile.bridgeUri case final bridgeUri?) {
      bridge = await _resolveAsset(bridgeUri);
    }

    return CodexProfileRuntimePlan(
      profile: profile,
      appServerOptions: CodexAppServerLaunchOptions(
        profileId: profile.id,
        canonicalCodexHome: installation.canonicalCodexHome,
        cliExecutable: installation.cliExecutable,
        configOverrides: List<String>.unmodifiable(config),
        environmentOverrides: Map<String, String>.unmodifiable(environment),
      ),
      bridgeScript: bridge,
      modelCatalog: catalog,
    );
  }

  Future<File> _resolveAsset(String uriText) async {
    final uri = Uri.tryParse(uriText);
    if (uri == null || uri.scheme != 'asset' || uri.host.isEmpty) {
      throw StateError('Unsupported portable Codex profile asset: $uriText');
    }
    final segments = <String>[
      uri.host,
      ...uri.pathSegments,
    ].where((segment) => segment.isNotEmpty).toList(growable: false);
    if (segments.isEmpty ||
        segments.any((segment) => segment == '.' || segment == '..')) {
      throw StateError('Unsafe portable Codex profile asset: $uriText');
    }
    final roots = <Directory>[
      if (assetRoot != null) assetRoot!.absolute,
      Directory(
        path.join(
          File(Platform.resolvedExecutable).parent.path,
          'data',
          'flutter_assets',
          'assets',
        ),
      ).absolute,
      Directory(path.join(Directory.current.path, 'assets')).absolute,
    ];
    for (final root in roots) {
      final candidate = File(
        path.joinAll(<String>[root.path, ...segments]),
      ).absolute;
      if (!_isWithin(root, candidate)) {
        continue;
      }
      if (await candidate.exists()) {
        return candidate;
      }
    }
    throw StateError('Packaged Codex profile asset is missing: $uriText');
  }
}

String _tomlString(String value) => jsonEncode(value);

bool _isWithin(Directory root, File candidate) {
  final normalizedRoot = path.windows.normalize(root.path).toLowerCase();
  final normalizedCandidate = path.windows
      .normalize(candidate.path)
      .toLowerCase();
  return normalizedCandidate == normalizedRoot ||
      path.windows.isWithin(normalizedRoot, normalizedCandidate);
}

void _validateManagedOpenAiBaseUrl(Uri uri) {
  if (uri.scheme != 'http' ||
      uri.host != '127.0.0.1' ||
      !uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw StateError('Managed OpenAI route must use numeric loopback HTTP.');
  }
}

Uri _chatGptBaseUrl(Uri managedBaseUrl) {
  final segments = managedBaseUrl.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: true);
  if (segments.isNotEmpty && segments.last == 'v1') {
    segments.removeLast();
  }
  return managedBaseUrl.replace(pathSegments: segments);
}
