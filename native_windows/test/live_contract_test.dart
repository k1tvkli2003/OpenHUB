import 'package:openhub_windows/src/core/api/local_api_client.dart';
import 'package:openhub_windows/src/data/openhub_repository.dart';
import 'package:openhub_windows/src/models/advanced_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const _endpointText = String.fromEnvironment('OPENHUB_CONTRACT_ENDPOINT');
const _codexHomeMarker = String.fromEnvironment(
  'OPENHUB_CONTRACT_CODEX_HOME_MARKER',
);

void main() {
  final skipReason = _endpointText.isEmpty || _codexHomeMarker.isEmpty
      ? 'Set OPENHUB_CONTRACT_ENDPOINT and OPENHUB_CONTRACT_CODEX_HOME_MARKER '
            'for an explicit disposable-fixture contract run.'
      : false;

  test(
    'native models decode the real local backend contract without credential material',
    () async {
      final client = LocalApiClient(endpoint: Uri.parse(_endpointText));
      final repository = OpenHubRepository(client);
      addTearDown(client.close);

      await repository.requireReady();
      final auth = await repository.getAuthSession();
      expect(auth.authenticated, isTrue);
      expect(auth.canRead, isTrue);

      final rawAccounts = await client.getObject('/api/accounts');
      expect(_containsSensitiveCredentialKey(rawAccounts), isFalse);
      final rawModelSources = await client.getObject('/api/model-sources/');
      expect(_containsSensitiveCredentialKey(rawModelSources), isFalse);
      final rawCodexIntegration = await client.getObject(
        '/api/codex-integration/status',
        query: <String, Object?>{'endpoint': _endpointText},
      );
      expect(_containsSensitiveCredentialKey(rawCodexIntegration), isFalse);

      final accounts = await repository.listAccounts();
      final overview = await repository.getOverview();
      final projections = await repository.getDashboardProjections();
      final requestLogs = await repository.getRequestLogs();
      final requestLogOptions = await repository.getRequestLogOptions();
      final trends = await repository.getAccountTrends(
        accounts.first.accountId,
      );
      final reports = await repository.getReports();
      final apiKeys = await repository.listApiKeys();
      final apiKeyAnalytics = apiKeys.isEmpty
          ? null
          : await repository.getApiKeyAnalytics(apiKeys.first.id);
      final automations = await repository.listAutomations();
      final automationRuns = await repository.listAutomationRuns();
      final settings = await repository.getSettings();
      final upstreamProxy = await repository.getUpstreamProxyAdmin();
      final modelSources = await repository.getModelSources();
      final firewall = await repository.getFirewallPolicy();
      final quotaPlanner = await repository.getQuotaPlannerSnapshot();
      final stickySessions = await repository.getStickySessions(
        const StickySessionsQuery(limit: 20),
      );
      final codexIntegration = await repository.getCodexIntegrationStatus();
      expect(accounts, isNotEmpty);
      expect(overview.accounts.length, accounts.length);
      expect(overview.primaryWindow.remainingPercent, inInclusiveRange(0, 100));
      expect(projections, isNotNull);
      expect(
        requestLogs.total,
        greaterThanOrEqualTo(requestLogs.requests.length),
      );
      expect(requestLogOptions.statuses, isA<List<String>>());
      expect(trends.accountId, accounts.first.accountId);
      expect(reports.summary.totalRequests, greaterThanOrEqualTo(0));
      expect(apiKeys, isA<List>());
      if (apiKeyAnalytics != null) {
        expect(apiKeyAnalytics.trends.keyId, apiKeys.first.id);
        expect(apiKeyAnalytics.usage7Day.keyId, apiKeys.first.id);
        expect(
          apiKeyAnalytics.usage7Day.totalRequests,
          greaterThanOrEqualTo(0),
        );
        expect(apiKeyAnalytics.usage7Day.totalTokens, greaterThanOrEqualTo(0));
      }
      expect(automations.total, greaterThanOrEqualTo(automations.items.length));
      expect(
        automationRuns.total,
        greaterThanOrEqualTo(automationRuns.items.length),
      );
      expect(settings.version, greaterThanOrEqualTo(1));
      expect(upstreamProxy.endpoints, isA<List>());
      expect(modelSources.sources, isA<List>());
      expect(firewall.mode, anyOf('allow_all', 'allowlist_active'));
      expect(quotaPlanner.forecast.horizonHours, greaterThan(0));
      expect(
        stickySessions.total,
        greaterThanOrEqualTo(stickySessions.entries.length),
      );
      expect(
        codexIntegration.managedBaseUrl,
        contains('/backend-api/codex-managed/v1'),
      );
      expect(codexIntegration.codexStatePolicy, 'never_mutate');
      expect(
        codexIntegration.statePath.toLowerCase(),
        contains(_codexHomeMarker.toLowerCase()),
      );
      expect(rawCodexIntegration.containsKey('configPath'), isFalse);
    },
    skip: skipReason,
  );
}

bool _containsSensitiveCredentialKey(Object? value) {
  const credentialNames = <String>{
    'accessToken',
    'refreshToken',
    'idToken',
    'access_token',
    'refresh_token',
    'id_token',
    'encryptionKey',
    'encryption_key',
  };
  const exportNames = <String>{'authJson', 'auth_json', 'tokens'};
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final exposesCredential =
          credentialNames.contains(key) && entry.value is String;
      final exposesExport = exportNames.contains(key);
      if (exposesCredential ||
          exposesExport ||
          _containsSensitiveCredentialKey(entry.value)) {
        return true;
      }
    }
  } else if (value is List) {
    return value.any(_containsSensitiveCredentialKey);
  }
  return false;
}
