import 'dart:convert';

import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';
import '../core/api/local_api_client.dart';
import '../models/account_summary.dart';
import '../models/account_operations.dart';
import '../models/advanced_settings.dart';
import '../models/api_key_info.dart';
import '../models/api_key_analytics.dart';
import '../models/auth_session.dart';
import '../models/automation_data.dart';
import '../models/codex_integration.dart';
import '../models/dashboard_overview.dart';
import '../models/dashboard_activity.dart';
import '../models/dashboard_settings.dart';
import '../models/reports_data.dart';
import '../models/runtime_control.dart';
import '../models/storage_cleanup.dart';

class OpenHubRepository {
  const OpenHubRepository(this._client);

  static const compatibleBackendVersion = '2.0.0';
  static const compatibleManagedRouteProtocol = '2';

  final LocalApiClient _client;

  Future<void> requireReady({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final response = await _client.getObject('/health/ready', timeout: timeout);
    final status = readString(response, 'status', 'health.ready');
    if (status != 'ok') {
      throw ApiException(
        message: 'The local openhub service is not ready: $status',
        code: 'backend_not_ready',
      );
    }
    final backendVersion = _client.lastAppVersion;
    if (backendVersion == null) {
      throw const ApiException(
        message:
            'The local openhub service did not identify its version. Refusing an unpinned backend.',
        code: 'backend_version_missing',
      );
    }
    if (backendVersion != compatibleBackendVersion) {
      throw ApiException(
        message:
            'Native client requires openhub $compatibleBackendVersion, but the local service is $backendVersion.',
        code: 'backend_version_mismatch',
      );
    }
    final checks = readNullableObject(response, 'checks', 'health.ready');
    final managedRouteProtocol = checks == null
        ? null
        : readNullableString(
            checks,
            'openhub_managed_route_protocol',
            'health.ready.checks',
          );
    if (managedRouteProtocol != compatibleManagedRouteProtocol) {
      throw ApiException(
        message:
            'The running openhub service belongs to an older OpenHUB build. Fully exit the older OpenHUB so its backend can stop, then open this version again.',
        code: 'backend_protocol_mismatch',
      );
    }
  }

  Future<AuthSession> getAuthSession() async {
    final response = await _client.getObject('/api/dashboard-auth/session');
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> loginPassword(String password) async {
    final response = await _client.postObject(
      '/api/dashboard-auth/password/login',
      body: <String, Object?>{'password': password},
    );
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> loginGuest({String? password}) async {
    final response = await _client.postObject(
      '/api/dashboard-auth/guest/login',
      body: <String, Object?>{
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> verifyTotp(String code) async {
    final response = await _client.postObject(
      '/api/dashboard-auth/totp/verify',
      body: <String, Object?>{'code': code},
    );
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> setupDashboardPassword(
    String password, {
    String? bootstrapToken,
  }) async {
    final response = await _client.postObject(
      '/api/dashboard-auth/password/setup',
      body: <String, Object?>{
        'password': password,
        if (bootstrapToken != null && bootstrapToken.isNotEmpty)
          'bootstrapToken': bootstrapToken,
      },
    );
    return AuthSession.fromJson(response);
  }

  Future<void> changeDashboardPassword(
    String currentPassword,
    String newPassword,
  ) async {
    final response = await _client.postObject(
      '/api/dashboard-auth/password/change',
      body: <String, Object?>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    _requireStatus(response, 'auth.passwordChange');
  }

  Future<void> removeDashboardPassword(String password) async {
    final response = await _client.deleteObject(
      '/api/dashboard-auth/password',
      body: <String, Object?>{'password': password},
    );
    _requireStatus(response, 'auth.passwordRemove');
  }

  Future<void> setGuestPassword(String password) async {
    final response = await _client.postObject(
      '/api/dashboard-auth/guest/password',
      body: <String, Object?>{'password': password},
    );
    _requireStatus(response, 'auth.guestPasswordSet');
  }

  Future<void> removeGuestPassword() async {
    final response = await _client.deleteObject(
      '/api/dashboard-auth/guest/password',
    );
    _requireStatus(response, 'auth.guestPasswordRemove');
  }

  Future<TotpSetupResult> startTotpSetup() async {
    final response = await _client.postObject(
      '/api/dashboard-auth/totp/setup/start',
    );
    return TotpSetupResult.fromJson(response);
  }

  Future<void> confirmTotpSetup(String secret, String code) async {
    final response = await _client.postObject(
      '/api/dashboard-auth/totp/setup/confirm',
      body: <String, Object?>{'secret': secret, 'code': code},
    );
    _requireStatus(response, 'auth.totpSetupConfirm');
  }

  Future<void> disableTotp(String code) async {
    final response = await _client.postObject(
      '/api/dashboard-auth/totp/disable',
      body: <String, Object?>{'code': code},
    );
    _requireStatus(response, 'auth.totpDisable');
  }

  Future<DashboardOverview> getOverview({String timeframe = '7d'}) async {
    final response = await _client.getObject(
      '/api/dashboard/overview',
      query: {'timeframe': timeframe},
    );
    return DashboardOverview.fromJson(response);
  }

  Future<DashboardProjections> getDashboardProjections() async {
    final response = await _client.getObject('/api/dashboard/projections');
    return DashboardProjections.fromJson(response);
  }

  Future<RequestLogsPage> getRequestLogs({
    RequestLogsQuery query = const RequestLogsQuery(),
  }) async {
    final response = await _client.getObject(
      '/api/request-logs',
      query: query.toQuery(),
    );
    return RequestLogsPage.fromJson(response);
  }

  Future<RequestLogOptions> getRequestLogOptions({
    RequestLogsQuery query = const RequestLogsQuery(),
  }) async {
    final listQuery = query.toQuery()
      ..remove('limit')
      ..remove('offset')
      ..remove('search')
      ..remove('status')
      ..remove('conversation_id');
    final response = await _client.getObject(
      '/api/request-logs/options',
      query: listQuery,
    );
    return RequestLogOptions.fromJson(response);
  }

  Future<List<AccountSummary>> listAccounts() async {
    final response = await _client.getObject('/api/accounts');
    return _readAccountsResponse(response);
  }

  Future<List<AccountSummary>> refreshAccounts() async {
    final response = await _client.postObject(
      '/api/accounts/refresh',
      timeout: const Duration(seconds: 45),
    );
    return _readAccountsResponse(response);
  }

  List<AccountSummary> _readAccountsResponse(Map<String, Object?> response) {
    final accounts = readList(response['accounts'], 'accounts.accounts')
        .map(
          (item) =>
              AccountSummary.fromJson(readObject(item, 'accounts.accounts[]')),
        )
        .toList(growable: false);
    if (accounts.length > 10000) {
      throw const ApiSchemaException(
        'Account count exceeds the native safety limit.',
      );
    }
    return accounts;
  }

  Future<ReportsData> getReports({
    ReportsQuery query = const ReportsQuery(),
  }) async {
    final response = await _client.getObject(
      '/api/reports',
      query: query.toQuery(),
    );
    return ReportsData.fromJson(response);
  }

  Future<List<ApiKeyInfo>> listApiKeys() async {
    final response = await _client.getList('/api/api-keys/');
    if (response.length > 10000) {
      throw const ApiSchemaException(
        'API key count exceeds the native safety limit.',
      );
    }
    return response
        .map((item) => ApiKeyInfo.fromJson(readObject(item, 'apiKeys[]')))
        .toList(growable: false);
  }

  Future<ApiKeyCreateResult> createApiKey(Map<String, Object?> payload) async {
    final response = await _client.postObject('/api/api-keys/', body: payload);
    return ApiKeyCreateResult.fromJson(response);
  }

  Future<ApiKeyInfo> updateApiKey(
    String keyId,
    Map<String, Object?> payload,
  ) async {
    final response = await _client.patchObject(
      '/api/api-keys/${Uri.encodeComponent(keyId)}',
      body: payload,
    );
    return ApiKeyInfo.fromJson(response);
  }

  Future<void> deleteApiKey(String keyId) async {
    await _client.deleteEmpty('/api/api-keys/${Uri.encodeComponent(keyId)}');
  }

  Future<ApiKeyCreateResult> regenerateApiKey(String keyId) async {
    final response = await _client.postObject(
      '/api/api-keys/${Uri.encodeComponent(keyId)}/regenerate',
    );
    return ApiKeyCreateResult.fromJson(response);
  }

  Future<List<ModelItem>> listModels() async {
    final response = await _client.getObject('/api/models');
    final models = readList(response['models'], 'models.models')
        .map((item) => ModelItem.fromJson(readObject(item, 'models.models[]')))
        .toList(growable: false);
    if (models.length > 10000) {
      throw const ApiSchemaException(
        'Model count exceeds the native safety limit.',
      );
    }
    return models;
  }

  Future<AutomationJobsPage> listAutomations({
    int limit = 200,
    int offset = 0,
    String? search,
    List<String> accountIds = const <String>[],
    List<String> models = const <String>[],
    List<String> statuses = const <String>[],
    List<String> scheduleTypes = const <String>[],
  }) async {
    final response = await _client.getObject(
      '/api/automations',
      query: <String, Object?>{
        'limit': limit,
        'offset': offset,
        'search': search,
        'accountId': accountIds,
        'model': models,
        'status': statuses,
        'scheduleType': scheduleTypes,
      },
    );
    return AutomationJobsPage.fromJson(response);
  }

  Future<AutomationRunsPage> listAutomationRuns({
    int limit = 100,
    int offset = 0,
    String? search,
    List<String> statuses = const <String>[],
    List<String> triggers = const <String>[],
    List<String> automationIds = const <String>[],
  }) async {
    final response = await _client.getObject(
      '/api/automations/runs',
      query: <String, Object?>{
        'limit': limit,
        'offset': offset,
        'search': search,
        'status': statuses,
        'trigger': triggers,
        'automationId': automationIds,
      },
    );
    return AutomationRunsPage.fromJson(response);
  }

  Future<AutomationJob> createAutomation(Map<String, Object?> payload) async {
    final response = await _client.postObject(
      '/api/automations',
      body: payload,
    );
    return AutomationJob.fromJson(response);
  }

  Future<AutomationJob> updateAutomation(
    String automationId,
    Map<String, Object?> payload,
  ) async {
    final response = await _client.patchObject(
      '/api/automations/${Uri.encodeComponent(automationId)}',
      body: payload,
    );
    return AutomationJob.fromJson(response);
  }

  Future<void> deleteAutomation(String automationId) async {
    final response = await _client.deleteObject(
      '/api/automations/${Uri.encodeComponent(automationId)}',
    );
    if (readString(response, 'status', 'automation.delete') != 'deleted') {
      throw const ApiSchemaException(
        'Automation delete did not confirm deletion.',
      );
    }
  }

  Future<AutomationRun> runAutomationNow(String automationId) async {
    final response = await _client.postObject(
      '/api/automations/${Uri.encodeComponent(automationId)}/run-now',
    );
    return AutomationRun.fromJson(response);
  }

  Future<AutomationRunDetails> getAutomationRunDetails(String runId) async {
    final response = await _client.getObject(
      '/api/automations/runs/${Uri.encodeComponent(runId)}/details',
    );
    return AutomationRunDetails.fromJson(response);
  }

  Future<DashboardSettings> getSettings() async {
    final response = await _client.getObject('/api/settings');
    return DashboardSettings.fromJson(response);
  }

  Future<StorageCleanupPreview> previewStorageCleanup({
    required List<StorageCleanupCategory> categories,
    required int olderThanDays,
  }) async {
    final response = await _client.postObject(
      '/api/storage-cleanup/preview',
      body: <String, Object?>{
        'categories': categories
            .map((category) => category.wireName)
            .toList(growable: false),
        'olderThanDays': olderThanDays,
      },
    );
    return StorageCleanupPreview.fromJson(response);
  }

  Future<StorageCleanupResult> applyStorageCleanup({
    required List<StorageCleanupCategory> categories,
    required int olderThanDays,
    required String confirmationToken,
  }) async {
    final response = await _client.postObject(
      '/api/storage-cleanup/apply',
      body: <String, Object?>{
        'categories': categories
            .map((category) => category.wireName)
            .toList(growable: false),
        'olderThanDays': olderThanDays,
        'confirmationToken': confirmationToken,
      },
    );
    return StorageCleanupResult.fromJson(response);
  }

  Future<ModelSourcesCatalog> getModelSources() async {
    final response = await _client.getObject('/api/model-sources/');
    return ModelSourcesCatalog.fromJson(response);
  }

  Future<ModelSource> createModelSource(Map<String, Object?> payload) async {
    final response = await _client.postObject(
      '/api/model-sources/',
      body: payload,
    );
    return ModelSource.fromJson(response);
  }

  Future<ModelSource> updateModelSource(
    String sourceId,
    Map<String, Object?> payload,
  ) async {
    final response = await _client.patchObject(
      '/api/model-sources/${Uri.encodeComponent(sourceId)}',
      body: payload,
    );
    return ModelSource.fromJson(response);
  }

  Future<void> deleteModelSource(String sourceId) async {
    await _client.deleteEmpty(
      '/api/model-sources/${Uri.encodeComponent(sourceId)}',
    );
  }

  Future<FirewallPolicy> getFirewallPolicy() async {
    final response = await _client.getObject('/api/firewall/ips');
    return FirewallPolicy.fromJson(response);
  }

  Future<FirewallEntry> addFirewallIp(String ipAddress) async {
    final response = await _client.postObject(
      '/api/firewall/ips',
      body: <String, Object?>{'ipAddress': ipAddress},
    );
    return FirewallEntry.fromJson(response);
  }

  Future<void> deleteFirewallIp(String ipAddress) async {
    final response = await _client.deleteObject(
      '/api/firewall/ips/${Uri.encodeComponent(ipAddress)}',
    );
    _requireStatus(response, 'firewall.delete');
  }

  Future<QuotaPlannerSnapshot> getQuotaPlannerSnapshot() async {
    final settingsFuture = _client.getObject('/api/quota-planner/settings');
    final decisionsFuture = _client.getList(
      '/api/quota-planner/decisions',
      query: const <String, Object?>{'limit': 20},
    );
    final forecastFuture = _client.getObject(
      '/api/quota-planner/forecast',
      query: const <String, Object?>{'horizonHours': 36},
    );
    final settingsResponse = await settingsFuture;
    final decisionsResponse = await decisionsFuture;
    final forecastResponse = await forecastFuture;
    final decisions = decisionsResponse
        .map(
          (item) => QuotaPlannerDecision.fromJson(
            readObject(item, 'quotaPlanner.decisions[]'),
          ),
        )
        .toList(growable: false);
    if (decisions.length > 100) {
      throw const ApiSchemaException(
        'Quota planner decision response exceeds the native safety limit.',
      );
    }
    return QuotaPlannerSnapshot(
      settings: QuotaPlannerSettings.fromJson(settingsResponse),
      decisions: decisions,
      forecast: QuotaPlannerForecast.fromJson(forecastResponse),
    );
  }

  Future<QuotaPlannerSettings> updateQuotaPlannerSettings(
    Map<String, Object?> payload,
  ) async {
    final response = await _client.putObject(
      '/api/quota-planner/settings',
      body: payload,
    );
    return QuotaPlannerSettings.fromJson(response);
  }

  Future<QuotaPlannerActionResult> warmQuotaPlannerAccount(
    String accountId, {
    String? model,
    bool forceProbe = false,
  }) async {
    final response = await _client.postObject(
      '/api/quota-planner/warm-now',
      body: <String, Object?>{
        'accountId': accountId,
        if (model != null && model.isNotEmpty) 'model': model,
        'forceProbe': forceProbe,
      },
      timeout: const Duration(seconds: 30),
    );
    return QuotaPlannerActionResult.fromJson(response);
  }

  Future<QuotaPlannerActionResult> cancelQuotaPlannerDecision(
    String decisionId,
  ) async {
    final response = await _client.postObject(
      '/api/quota-planner/decisions/'
      '${Uri.encodeComponent(decisionId)}/cancel',
    );
    return QuotaPlannerActionResult.fromJson(response);
  }

  Future<StickySessionsPage> getStickySessions(
    StickySessionsQuery query,
  ) async {
    final response = await _client.getObject(
      '/api/sticky-sessions',
      query: query.toQuery(),
    );
    return StickySessionsPage.fromJson(response);
  }

  Future<void> deleteStickySession(StickySessionEntry entry) async {
    final response = await _client.deleteObject(
      '/api/sticky-sessions/${Uri.encodeComponent(entry.kind)}/'
      '${Uri.encodeComponent(entry.key)}',
    );
    _requireStatus(response, 'stickySessions.delete');
  }

  Future<int> purgeStaleStickySessions() async {
    final response = await _client.postObject(
      '/api/sticky-sessions/purge',
      body: const <String, Object?>{'staleOnly': true},
    );
    return readInt(response, 'deletedCount', 'stickySessions.purge');
  }

  Future<DashboardSettings> updateSettings(
    DashboardSettings current,
    Map<String, Object?> changes,
  ) async {
    if (changes.containsKey('expectedVersion')) {
      throw ArgumentError('expectedVersion is managed by the native client.');
    }
    final response = await _client.putObject(
      '/api/settings',
      body: <String, Object?>{'expectedVersion': current.version, ...changes},
    );
    return DashboardSettings.fromJson(response);
  }

  Future<CodexIntegrationStatus> getCodexIntegrationStatus() async {
    final response = await _client.getObject(
      '/api/codex-integration/status',
      query: <String, Object?>{'endpoint': _managementEndpoint},
    );
    return CodexIntegrationStatus.fromJson(response);
  }

  Future<RuntimeControlSnapshot> getRuntimeControlSnapshot() async {
    final response = await _client.getObject('/api/runtime-control/snapshot');
    return RuntimeControlSnapshot.fromJson(response);
  }

  Future<RuntimeTaskActionResult> controlRuntimeTask({
    required AgentRuntime runtime,
    required String nativeId,
    required String action,
  }) async {
    final response = await _client.postObject(
      '/api/runtime-control/tasks/${runtime.name}/'
      '${Uri.encodeComponent(nativeId)}/${Uri.encodeComponent(action)}',
      timeout: const Duration(seconds: 40),
    );
    return RuntimeTaskActionResult.fromJson(response);
  }

  Future<CodexLaunchRoute> getCodexLaunchRoute() async {
    final response = await _client.getObject(
      '/api/codex-integration/launch-route',
    );
    return CodexLaunchRoute.fromJson(response);
  }

  Future<CodexLaunchPreparation> prepareCodexLaunch(
    CodexLaunchRoute current, {
    String? accountId,
  }) async {
    final response = await _client.postObject(
      '/api/codex-integration/prepare-launch',
      body: <String, Object?>{
        'endpoint': _managementEndpoint,
        'expectedRevision': current.revision,
        'accountId': ?accountId,
        'confirmed': true,
      },
      timeout: const Duration(seconds: 90),
    );
    return CodexLaunchPreparation.fromJson(response);
  }

  Future<ApiKeyAnalytics> getApiKeyAnalytics(String keyId) async {
    final encodedId = Uri.encodeComponent(keyId);
    final trendsFuture = _client.getObject('/api/api-keys/$encodedId/trends');
    final usageFuture = _client.getObject('/api/api-keys/$encodedId/usage-7d');
    final trends = await trendsFuture;
    final usage = await usageFuture;
    final parsedTrends = ApiKeyTrends.fromJson(trends);
    final parsedUsage = ApiKeyUsage7Day.fromJson(usage);
    if (parsedTrends.keyId != keyId || parsedUsage.keyId != keyId) {
      throw const ApiSchemaException(
        'API-key analytics response does not match the requested key.',
      );
    }
    return ApiKeyAnalytics(trends: parsedTrends, usage7Day: parsedUsage);
  }

  Future<CodexIntegrationMutation> setCodexManagedRoutingEnabled(
    CodexIntegrationStatus current, {
    required bool enabled,
  }) async {
    final response = await _client.postObject(
      '/api/codex-integration/mode',
      body: <String, Object?>{
        'endpoint': _managementEndpoint,
        'expectedRevision': current.revision,
        'enabled': enabled,
        'confirmed': true,
      },
      timeout: const Duration(seconds: 15),
    );
    return CodexIntegrationMutation.fromJson(response);
  }

  String get _managementEndpoint {
    final endpoint = _client.endpoint;
    return endpoint.replace(path: '', query: null, fragment: null).toString();
  }

  Future<UpstreamProxyAdmin> getUpstreamProxyAdmin() async {
    final response = await _client.getObject('/api/settings/upstream-proxy');
    return UpstreamProxyAdmin.fromJson(response);
  }

  Future<UpstreamProxyEndpoint> createUpstreamProxyEndpoint(
    Map<String, Object?> payload,
  ) async {
    final response = await _client.postObject(
      '/api/settings/upstream-proxy/endpoints',
      body: payload,
    );
    return UpstreamProxyEndpoint.fromJson(response);
  }

  Future<UpstreamProxyTestResult> testUpstreamProxyEndpoint(
    String endpointId,
  ) async {
    final response = await _client.postObject(
      '/api/settings/upstream-proxy/endpoints/'
      '${Uri.encodeComponent(endpointId)}/test',
      timeout: const Duration(seconds: 20),
    );
    return UpstreamProxyTestResult.fromJson(response);
  }

  Future<UpstreamProxyPool> createUpstreamProxyPool(
    Map<String, Object?> payload,
  ) async {
    final response = await _client.postObject(
      '/api/settings/upstream-proxy/pools',
      body: payload,
    );
    return UpstreamProxyPool.fromJson(response);
  }

  Future<UpstreamProxyPool> addUpstreamProxyPoolMember(
    String poolId,
    Map<String, Object?> payload,
  ) async {
    final response = await _client.postObject(
      '/api/settings/upstream-proxy/pools/'
      '${Uri.encodeComponent(poolId)}/members',
      body: payload,
    );
    return UpstreamProxyPool.fromJson(response);
  }

  Future<AccountProxyBinding> putAccountProxyBinding(
    String accountId,
    String poolId, {
    bool isActive = true,
  }) async {
    final response = await _client.putObject(
      '/api/settings/upstream-proxy/accounts/'
      '${Uri.encodeComponent(accountId)}/binding',
      body: <String, Object?>{'poolId': poolId, 'isActive': isActive},
    );
    return AccountProxyBinding.fromJson(response);
  }

  Future<void> pauseAccount(String accountId) async {
    await _client.postObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}/pause',
    );
  }

  Future<void> reactivateAccount(String accountId) async {
    await _client.postObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}/reactivate',
    );
  }

  Future<AccountImportResult> importAccountJson(String rawJson) async {
    final bytes = utf8.encode(rawJson);
    final response = await _client.postMultipartObject(
      '/api/accounts/import',
      fieldName: 'auth_json',
      filename: 'auth.json',
      bytes: bytes,
    );
    return AccountImportResult.fromJson(response);
  }

  Future<void> setAccountAlias(String accountId, String? alias) async {
    await _client.putObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}/alias',
      body: <String, Object?>{'alias': alias},
    );
  }

  Future<void> updateAccountSecurityAuthorization(
    String accountId,
    bool authorized,
  ) async {
    await _client.patchObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}',
      body: <String, Object?>{'securityWorkAuthorized': authorized},
    );
  }

  Future<void> updateAccountLimitWarmup(String accountId, bool enabled) async {
    await _client.putObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}/limit-warmup',
      body: <String, Object?>{'enabled': enabled},
    );
  }

  Future<void> updateAccountRoutingPolicy(
    String accountId,
    String policy,
  ) async {
    await _client.putObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}/routing-policy',
      body: <String, Object?>{'routingPolicy': policy},
    );
  }

  Future<AccountTrends> getAccountTrends(String accountId) async {
    final response = await _client.getObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}/trends',
    );
    return AccountTrends.fromJson(response);
  }

  Future<AccountUsageResetCredits> getAccountUsageResetCredits(
    String accountId,
  ) async {
    final response = await _client.getObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}/usage-reset-credits',
    );
    return AccountUsageResetCredits.fromJson(response);
  }

  Future<AccountProbeResult> probeAccount(
    String accountId, {
    String? model,
  }) async {
    final response = await _client.postObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}/probe',
      body: model == null || model.trim().isEmpty
          ? null
          : <String, Object?>{'model': model.trim()},
      timeout: const Duration(seconds: 45),
    );
    return AccountProbeResult.fromJson(response);
  }

  Future<AccountUsageResetResult> consumeAccountUsageResetCredit(
    String accountId, {
    required String redeemRequestId,
  }) async {
    final response = await _client.postObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}'
      '/usage-reset-credits/consume',
      body: <String, Object?>{'redeemRequestId': redeemRequestId},
      timeout: const Duration(seconds: 45),
    );
    return AccountUsageResetResult.fromJson(response);
  }

  Future<void> deleteAccount(
    String accountId, {
    required bool deleteHistory,
  }) async {
    await _client.deleteObject(
      '/api/accounts/${Uri.encodeComponent(accountId)}',
      query: <String, Object?>{'delete_history': deleteHistory},
    );
  }

  Future<OauthStartResult> startOauth({
    String? forceMethod,
    String? accountId,
  }) async {
    final body = <String, Object?>{};
    if (forceMethod != null) {
      body['forceMethod'] = forceMethod;
    }
    if (accountId != null) {
      body['accountId'] = accountId;
    }
    final response = await _client.postObject(
      '/api/oauth/start',
      body: body,
      timeout: const Duration(seconds: 30),
    );
    return OauthStartResult.fromJson(response);
  }

  Future<OauthStatusResult> getOauthStatus({String? flowId}) async {
    final response = await _client.getObject(
      '/api/oauth/status',
      query: <String, Object?>{'flowId': flowId},
    );
    return OauthStatusResult.fromJson(response);
  }

  Future<OauthStatusResult> completeOauth(OauthStartResult flow) async {
    final response = await _client.postObject(
      '/api/oauth/complete',
      body: <String, Object?>{
        if (flow.flowId != null) 'flowId': flow.flowId,
        if (flow.deviceAuthId != null) 'deviceAuthId': flow.deviceAuthId,
        if (flow.userCode != null) 'userCode': flow.userCode,
      },
      timeout: const Duration(seconds: 30),
    );
    return OauthStatusResult.fromJson(response);
  }

  Future<OauthStatusResult> submitManualOauthCallback(
    String callbackUrl, {
    String? flowId,
  }) async {
    final body = <String, Object?>{'callbackUrl': callbackUrl};
    if (flowId != null) {
      body['flowId'] = flowId;
    }
    final response = await _client.postObject(
      '/api/oauth/manual-callback',
      body: body,
    );
    return OauthStatusResult.fromJson(response);
  }

  Future<void> startDrain() async {
    await _client.postEmpty(
      '/internal/drain/start',
      timeout: const Duration(seconds: 2),
    );
  }

  static void _requireStatus(Map<String, Object?> response, String context) {
    final status = readString(response, 'status', context).trim();
    if (status.isEmpty) {
      throw ApiSchemaException('$context.status must not be empty.');
    }
  }
}
