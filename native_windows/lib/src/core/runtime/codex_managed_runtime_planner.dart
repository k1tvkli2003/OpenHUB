import 'codex_app_server_supervisor.dart';
import 'codex_installation_discovery.dart';

class CodexManagedRuntimePlan {
  const CodexManagedRuntimePlan({required this.appServerOptions});

  final CodexAppServerLaunchOptions appServerOptions;
}

/// Builds one provider-neutral Codex app-server attachment.
///
/// OpenHUB owns only the loopback account route. Codex keeps ownership of its
/// model catalog and selected model, so this plan intentionally injects no
/// provider or model override.
class CodexManagedRuntimePlanner {
  const CodexManagedRuntimePlanner();

  CodexManagedRuntimePlan build({
    required CodexInstallation installation,
    required Uri managedOpenAiBaseUrl,
  }) {
    _validateManagedOpenAiBaseUrl(managedOpenAiBaseUrl);
    return CodexManagedRuntimePlan(
      appServerOptions: CodexAppServerLaunchOptions(
        profileId: 'openhub-openai-router',
        canonicalCodexHome: installation.canonicalCodexHome,
        cliExecutable: installation.cliExecutable,
        configOverrides: const <String>[],
        environmentOverrides: <String, String>{
          'CODEX_APP_SERVER_OPENAI_BASE_URL': managedOpenAiBaseUrl.toString(),
          'CODEX_APP_SERVER_CHATGPT_BASE_URL': _chatGptBaseUrl(
            managedOpenAiBaseUrl,
          ).toString(),
        },
      ),
    );
  }
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
