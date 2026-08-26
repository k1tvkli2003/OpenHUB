import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../core/api/local_api_client.dart';
import '../core/performance_probe.dart';
import '../core/runtime/backend_supervisor.dart';
import '../core/runtime/codex_app_server_supervisor.dart';
import '../core/runtime/codex_desktop_launcher.dart';
import '../core/runtime/codex_installation_discovery.dart';
import '../core/runtime/codex_profile_runtime_planner.dart';
import '../core/runtime/codex_task_lifecycle_service.dart';
import '../core/runtime/ox_bridge_supervisor.dart';
import '../core/runtime/runtime_config.dart';
import '../data/openhub_repository.dart';
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
import 'async_section.dart';

enum AppDestination { pulse, reports, accounts, apis, settings, automations }

enum RuntimePhase { checking, starting, ready, unavailable, stopping }

enum CodexManagedLaunchDisposition {
  launchedManaged,
  launchedNormal,
  alreadyRunning,
  blocked,
}

enum CodexProfileSwitchDisposition {
  unchanged,
  confirmationRequired,
  switched,
  rolledBack,
  failed,
}

class CodexProfileSwitchOutcome {
  const CodexProfileSwitchOutcome({
    required this.disposition,
    required this.previousProfileId,
    required this.targetProfileId,
    required this.liveRootCount,
    required this.liveDescendantCount,
    this.error,
    this.rollbackError,
  });

  final CodexProfileSwitchDisposition disposition;
  final String previousProfileId;
  final String targetProfileId;
  final int liveRootCount;
  final int liveDescendantCount;
  final Object? error;
  final Object? rollbackError;

  bool get requiresConfirmation =>
      disposition == CodexProfileSwitchDisposition.confirmationRequired;
  bool get succeeded =>
      disposition == CodexProfileSwitchDisposition.unchanged ||
      disposition == CodexProfileSwitchDisposition.switched;
}

class CodexManagedLaunchOutcome {
  const CodexManagedLaunchOutcome({
    required this.disposition,
    required this.route,
    this.preparation,
  });

  final CodexManagedLaunchDisposition disposition;
  final CodexLaunchRoute route;
  final CodexLaunchPreparation? preparation;
}

class RuntimeViewState {
  const RuntimeViewState({required this.phase, this.connection, this.error});

  const RuntimeViewState.checking() : this(phase: RuntimePhase.checking);

  final RuntimePhase phase;
  final BackendConnection? connection;
  final Object? error;

  bool get isReady => phase == RuntimePhase.ready;
}

class AppController extends ChangeNotifier {
  AppController({
    required RuntimeConfig config,
    this.performanceProbe,
    DateTime? sessionStartedAt,
    OpenHubRepository? repository,
    CodexDesktopLauncher? codexDesktopLauncher,
    WindowsCodexInstallationDiscovery? codexInstallationDiscovery,
    CodexAppServerSupervisor? codexAppServerSupervisor,
    CodexProfileRuntimePlanner? codexProfileRuntimePlanner,
    OxBridgeSupervisor? oxBridgeSupervisor,
    bool? managedAppServerEnabled,
  }) : _client = LocalApiClient(endpoint: config.endpoint),
       _config = config,
       _managedAppServerEnabled = managedAppServerEnabled ?? repository == null,
       sessionStartedAt = (sessionStartedAt ?? DateTime.now()).toUtc() {
    _repository = repository ?? OpenHubRepository(_client);
    _supervisor = BackendSupervisor(config, _repository);
    _codexDesktopLauncher =
        codexDesktopLauncher ?? const WindowsCodexDesktopLauncher();
    _codexInstallationDiscovery =
        codexInstallationDiscovery ?? WindowsCodexInstallationDiscovery();
    _codexAppServerSupervisor =
        codexAppServerSupervisor ?? CodexAppServerSupervisor();
    _codexProfileRuntimePlanner =
        codexProfileRuntimePlanner ?? const CodexProfileRuntimePlanner();
    _oxBridgeSupervisor = oxBridgeSupervisor ?? OxBridgeSupervisor();
  }

  final RuntimeConfig _config;
  final bool _managedAppServerEnabled;

  /// Stable boundary used by the UI to distinguish cached samples from data
  /// refreshed during this OpenHUB process. It never alters account data.
  final DateTime sessionStartedAt;
  final NativePerformanceProbe? performanceProbe;
  final LocalApiClient _client;
  late final OpenHubRepository _repository;
  late final BackendSupervisor _supervisor;
  late final CodexDesktopLauncher _codexDesktopLauncher;
  late final WindowsCodexInstallationDiscovery _codexInstallationDiscovery;
  late final CodexAppServerSupervisor _codexAppServerSupervisor;
  late final CodexProfileRuntimePlanner _codexProfileRuntimePlanner;
  late final OxBridgeSupervisor _oxBridgeSupervisor;

  RuntimeViewState runtime = const RuntimeViewState.checking();
  AsyncSection<AuthSession> auth = const AsyncSection<AuthSession>();
  AsyncSection<DashboardOverview> overview =
      const AsyncSection<DashboardOverview>();
  AsyncSection<DashboardProjections> projections =
      const AsyncSection<DashboardProjections>();
  AsyncSection<RequestLogsPage> requestLogs =
      const AsyncSection<RequestLogsPage>();
  AsyncSection<RequestLogOptions> requestLogOptions =
      const AsyncSection<RequestLogOptions>();
  AsyncSection<List<AccountSummary>> accounts =
      const AsyncSection<List<AccountSummary>>();
  AsyncSection<ReportsData> reports = const AsyncSection<ReportsData>();
  AsyncSection<List<ApiKeyInfo>> apiKeys =
      const AsyncSection<List<ApiKeyInfo>>();
  final Map<String, AsyncSection<ApiKeyAnalytics>> apiKeyAnalytics =
      <String, AsyncSection<ApiKeyAnalytics>>{};
  AsyncSection<List<ModelItem>> models = const AsyncSection<List<ModelItem>>();
  AsyncSection<AutomationJobsPage> automations =
      const AsyncSection<AutomationJobsPage>();
  AsyncSection<AutomationRunsPage> automationRuns =
      const AsyncSection<AutomationRunsPage>();
  AsyncSection<DashboardSettings> settings =
      const AsyncSection<DashboardSettings>();
  AsyncSection<UpstreamProxyAdmin> upstreamProxy =
      const AsyncSection<UpstreamProxyAdmin>();
  AsyncSection<ModelSourcesCatalog> modelSources =
      const AsyncSection<ModelSourcesCatalog>();
  AsyncSection<FirewallPolicy> firewall = const AsyncSection<FirewallPolicy>();
  AsyncSection<QuotaPlannerSnapshot> quotaPlanner =
      const AsyncSection<QuotaPlannerSnapshot>();
  AsyncSection<StickySessionsPage> stickySessions =
      const AsyncSection<StickySessionsPage>();
  AsyncSection<CodexIntegrationStatus> codexIntegration =
      const AsyncSection<CodexIntegrationStatus>();
  AsyncSection<CodexLaunchRoute> codexLaunchRoute =
      const AsyncSection<CodexLaunchRoute>();
  AsyncSection<CodexInstallation> codexInstallation =
      const AsyncSection<CodexInstallation>();
  AsyncSection<CodexProfileRegistry> codexProfiles =
      const AsyncSection<CodexProfileRegistry>();
  CodexTaskSwitchPreflight? lastCodexProfileSwitchPreflight;
  CodexProfileSwitchOutcome? lastCodexProfileSwitchOutcome;
  OxBridgeHealth? oxBridgeHealth;
  CodexLaunchPreparation? lastCodexLaunchPreparation;
  String? selectedManualCodexAccountId;
  AccountRemainingUsageOrder accountRemainingUsageOrder =
      AccountRemainingUsageOrder.highestFirst;
  DateTime? lastAccountUsageRefreshStartedAt;
  DateTime? lastAccountUsageRefreshFinishedAt;
  Set<String> accountUsageRefreshSucceededIds = <String>{};
  Set<String> accountUsageRefreshFailedIds = <String>{};
  AppDestination destination = AppDestination.accounts;
  String overviewTimeframe = '7d';
  ReportsQuery reportsQuery = const ReportsQuery();
  RequestLogsQuery requestLogsQuery = const RequestLogsQuery();
  StickySessionsQuery stickySessionsQuery = const StickySessionsQuery();
  final Set<String> mutatingAccountIds = <String>{};
  final Set<String> mutatingApiKeyIds = <String>{};
  final Set<String> mutatingAutomationIds = <String>{};
  bool authActionBusy = false;
  bool accountGlobalActionBusy = false;
  bool settingsActionBusy = false;
  bool storageCleanupActionBusy = false;
  bool apiKeyActionBusy = false;
  bool automationActionBusy = false;
  bool proxyActionBusy = false;
  bool advancedSettingsActionBusy = false;
  bool codexIntegrationActionBusy = false;
  bool codexLaunchActionBusy = false;
  bool codexProfileActionBusy = false;
  bool codexModeChangeAffectsNextLaunch = false;
  Object? authActionError;
  Object? accountActionError;
  Object? apiKeyActionError;
  Object? automationActionError;
  Object? settingsActionError;
  Object? storageCleanupActionError;
  StorageCleanupPreview? storageCleanupPreview;
  StorageCleanupResult? lastStorageCleanupResult;
  Object? proxyActionError;
  Object? advancedSettingsActionError;
  Object? codexIntegrationActionError;
  Object? codexLaunchActionError;
  Object? codexProfileActionError;
  Object? codexTaskActionError;
  Object? runtimeTaskActionError;
  final Set<String> mutatingCodexTaskIds = <String>{};
  final Set<String> mutatingRuntimeTaskIds = <String>{};
  final Set<String> pausedCodexTaskIds = <String>{};
  final Set<String> codexTaskContinuationRequiredIds = <String>{};

  Future<void>? _initialization;
  Future<void>? _overviewRefresh;
  Future<void>? _projectionsRefresh;
  Future<void>? _requestLogsRefresh;
  Future<void>? _requestLogOptionsRefresh;
  Future<void>? _accountsRefresh;
  Future<void>? _accountUsageRefresh;
  Future<void>? _reportsRefresh;
  Future<void>? _apiKeysRefresh;
  final Map<String, Future<void>> _apiKeyAnalyticsRefresh =
      <String, Future<void>>{};
  Future<void>? _modelsRefresh;
  Future<void>? _automationsRefresh;
  Future<void>? _automationRunsRefresh;
  Future<void>? _settingsRefresh;
  Future<void>? _upstreamProxyRefresh;
  Future<void>? _modelSourcesRefresh;
  Future<void>? _firewallRefresh;
  Future<void>? _quotaPlannerRefresh;
  Future<void>? _stickySessionsRefresh;
  Future<void>? _codexIntegrationRefresh;
  Future<void>? _codexLaunchRouteRefresh;
  Future<void>? _codexInstallationRefresh;
  Future<void>? _codexProfilesRefresh;
  Future<CodexManagedLaunchOutcome?>? _codexManagedLaunch;
  bool _disposed = false;

  RuntimeConfig get config => _config;
  bool get canWrite => auth.value?.canWrite ?? false;
  bool get currentDestinationBusy => switch (destination) {
    AppDestination.pulse => false,
    AppDestination.reports =>
      reports.isBusy ||
          overview.isBusy ||
          projections.isBusy ||
          requestLogs.isBusy ||
          requestLogOptions.isBusy ||
          codexLaunchRoute.isBusy,
    AppDestination.accounts => accounts.isBusy,
    AppDestination.apis => apiKeys.isBusy || models.isBusy,
    AppDestination.settings =>
      settings.isBusy ||
          codexIntegration.isBusy ||
          codexLaunchRoute.isBusy ||
          codexInstallation.isBusy ||
          codexProfiles.isBusy ||
          codexLaunchActionBusy ||
          codexProfileActionBusy ||
          upstreamProxy.isBusy ||
          modelSources.isBusy ||
          firewall.isBusy ||
          quotaPlanner.isBusy ||
          stickySessions.isBusy,
    AppDestination.automations =>
      automations.isBusy || automationRuns.isBusy || models.isBusy,
  };

  Future<void> initialize() {
    return _initialization ??= _initialize().whenComplete(
      () => _initialization = null,
    );
  }

  Future<void> _initialize() async {
    runtime = const RuntimeViewState(phase: RuntimePhase.checking);
    _notify();
    try {
      runtime = const RuntimeViewState(phase: RuntimePhase.starting);
      _notify();
      final connection = await _supervisor.ensureReady();
      runtime = RuntimeViewState(
        phase: RuntimePhase.ready,
        connection: connection,
      );
      performanceProbe?.markRuntimeActionable('ready');
      _notify();
      await refreshAuth();
      if (auth.value?.authenticated ?? false) {
        if (_managedAppServerEnabled) {
          unawaited(refreshCodexInstallation());
          unawaited(refreshCodexProfiles());
        }
        if (_config.launchCodexOnReady) {
          await openCodex();
          await Future.wait<void>(<Future<void>>[
            refreshCore(includeLaunchCritical: false),
            if (codexIntegration.value == null) refreshCodexIntegration(),
            if (codexLaunchRoute.value == null) refreshCodexLaunchRoute(),
          ]);
        } else {
          await refreshCore();
        }
        if (canWrite && performanceProbe?.syntheticAccountRows == null) {
          // Hydrate cached rows first so Accounts becomes usable quickly, then
          // immediately replace them with current upstream quota evidence.
          // This refresh is intentionally non-blocking for the rest of startup.
          unawaited(refreshAccountUsage());
        }
        _installSyntheticPerformanceAccounts();
      } else if (_config.launchCodexOnReady) {
        codexLaunchActionError = StateError(
          'Managed Codex launch requires an authenticated writable local dashboard session.',
        );
        _notify();
      }
    } on Object catch (error) {
      runtime = RuntimeViewState(phase: RuntimePhase.unavailable, error: error);
      performanceProbe?.markRuntimeActionable('unavailable');
      _notify();
    }
  }

  Future<void> refreshAuth() async {
    auth = auth.begin();
    _notify();
    try {
      auth = auth.succeed(await _repository.getAuthSession());
    } on Object catch (error) {
      auth = auth.fail(error);
    }
    _notify();
  }

  Future<void> loginPassword(String password) async {
    await _runAuthAction(() => _repository.loginPassword(password));
  }

  Future<void> loginGuest({String? password}) async {
    await _runAuthAction(() => _repository.loginGuest(password: password));
  }

  Future<void> verifyTotp(String code) async {
    await _runAuthAction(() => _repository.verifyTotp(code));
  }

  Future<void> _runAuthAction(Future<AuthSession> Function() action) async {
    if (authActionBusy) {
      return;
    }
    authActionBusy = true;
    authActionError = null;
    _notify();
    try {
      final result = await action();
      auth = auth.succeed(result);
      if (result.authenticated) {
        await refreshCore();
      }
    } on Object catch (error) {
      authActionError = error;
    } finally {
      authActionBusy = false;
      _notify();
    }
  }

  Future<bool> setupDashboardPassword(
    String password, {
    String? bootstrapToken,
  }) {
    return _runAuthManagement(() async {
      await _repository.setupDashboardPassword(
        password,
        bootstrapToken: bootstrapToken,
      );
    });
  }

  Future<bool> changeDashboardPassword(
    String currentPassword,
    String newPassword,
  ) {
    return _runAuthManagement(
      () => _repository.changeDashboardPassword(currentPassword, newPassword),
    );
  }

  Future<bool> removeDashboardPassword(String password) {
    return _runAuthManagement(
      () => _repository.removeDashboardPassword(password),
    );
  }

  Future<bool> setGuestPassword(String password) {
    return _runAuthManagement(() => _repository.setGuestPassword(password));
  }

  Future<bool> removeGuestPassword() {
    return _runAuthManagement(_repository.removeGuestPassword);
  }

  Future<TotpSetupResult?> startTotpSetup() async {
    if (!canWrite || authActionBusy) {
      return null;
    }
    authActionBusy = true;
    authActionError = null;
    _notify();
    try {
      return await _repository.startTotpSetup();
    } on Object catch (error) {
      authActionError = error;
      return null;
    } finally {
      authActionBusy = false;
      _notify();
    }
  }

  Future<bool> confirmTotpSetup(String secret, String code) {
    return _runAuthManagement(() => _repository.confirmTotpSetup(secret, code));
  }

  Future<bool> disableTotp(String code) {
    return _runAuthManagement(() => _repository.disableTotp(code));
  }

  Future<bool> _runAuthManagement(Future<void> Function() action) async {
    if (!canWrite || authActionBusy) {
      return false;
    }
    authActionBusy = true;
    authActionError = null;
    _notify();
    try {
      await action();
      await Future.wait<void>(<Future<void>>[
        refreshAuth(),
        if (settings.value != null) refreshSettings(),
      ]);
      return true;
    } on Object catch (error) {
      authActionError = error;
      return false;
    } finally {
      authActionBusy = false;
      _notify();
    }
  }

  Future<void> refreshCore({bool includeLaunchCritical = true}) async {
    await Future.wait<void>(<Future<void>>[
      refreshOverview(),
      refreshAccounts(),
      refreshDashboardProjections(),
      refreshRequestLogs(),
      refreshRequestLogOptions(),
      if (includeLaunchCritical) refreshCodexIntegration(),
      if (includeLaunchCritical) refreshCodexLaunchRoute(),
    ]);
  }

  Future<void> refreshOverview({String? timeframe}) {
    if (timeframe != null && timeframe != overviewTimeframe) {
      overviewTimeframe = timeframe;
      _overviewRefresh = null;
    }
    return _overviewRefresh ??= _loadOverview().whenComplete(
      () => _overviewRefresh = null,
    );
  }

  Future<void> _loadOverview() async {
    overview = overview.begin();
    _notify();
    try {
      final result = await _repository.getOverview(
        timeframe: overviewTimeframe,
      );
      overview = overview.succeed(result, sourceSampleAt: result.lastSyncAt);
    } on Object catch (error) {
      overview = overview.fail(error);
    }
    _notify();
  }

  Future<void> refreshDashboardProjections() {
    return _projectionsRefresh ??= _loadDashboardProjections().whenComplete(
      () => _projectionsRefresh = null,
    );
  }

  Future<void> _loadDashboardProjections() async {
    projections = projections.begin();
    _notify();
    try {
      projections = projections.succeed(
        await _repository.getDashboardProjections(),
      );
    } on Object catch (error) {
      projections = projections.fail(error);
    }
    _notify();
  }

  Future<void> refreshRequestLogs({RequestLogsQuery? query}) {
    if (query != null && query != requestLogsQuery) {
      requestLogsQuery = query;
      _requestLogsRefresh = null;
    }
    return _requestLogsRefresh ??= _loadRequestLogs().whenComplete(
      () => _requestLogsRefresh = null,
    );
  }

  Future<void> _loadRequestLogs() async {
    requestLogs = requestLogs.begin();
    _notify();
    try {
      final result = await _repository.getRequestLogs(query: requestLogsQuery);
      requestLogs = requestLogs.succeed(
        result,
        sourceSampleAt: result.requests.firstOrNull?.requestedAt,
      );
    } on Object catch (error) {
      requestLogs = requestLogs.fail(error);
    }
    _notify();
  }

  Future<void> refreshRequestLogOptions({RequestLogsQuery? query}) {
    if (query != null && query != requestLogsQuery) {
      requestLogsQuery = query;
      _requestLogOptionsRefresh = null;
    }
    return _requestLogOptionsRefresh ??= _loadRequestLogOptions().whenComplete(
      () => _requestLogOptionsRefresh = null,
    );
  }

  Future<void> _loadRequestLogOptions() async {
    requestLogOptions = requestLogOptions.begin();
    _notify();
    try {
      requestLogOptions = requestLogOptions.succeed(
        await _repository.getRequestLogOptions(query: requestLogsQuery),
      );
    } on Object catch (error) {
      requestLogOptions = requestLogOptions.fail(error);
    }
    _notify();
  }

  Future<void> updateRequestLogsQuery(RequestLogsQuery query) async {
    final changed = query != requestLogsQuery;
    if (!changed) {
      return;
    }
    requestLogsQuery = query;
    final pending = <Future<void>?>[
      _requestLogsRefresh,
      _requestLogOptionsRefresh,
    ].whereType<Future<void>>().toList(growable: false);
    if (pending.isNotEmpty) {
      await Future.wait<void>(pending);
    }
    _requestLogsRefresh = null;
    _requestLogOptionsRefresh = null;
    await Future.wait<void>(<Future<void>>[
      refreshRequestLogs(),
      refreshRequestLogOptions(),
    ]);
  }

  Future<void> refreshAccounts() {
    return _accountsRefresh ??= _loadAccounts().whenComplete(
      () => _accountsRefresh = null,
    );
  }

  Future<void> _loadAccounts() async {
    accounts = accounts.begin();
    _notify();
    try {
      final result = await _repository.listAccounts();
      DateTime? latestSample;
      for (final account in result) {
        final sample = account.usageSampleAt;
        if (sample != null &&
            (latestSample == null || sample.isAfter(latestSample))) {
          latestSample = sample;
        }
      }
      accounts = accounts.succeed(result, sourceSampleAt: latestSample);
    } on Object catch (error) {
      accounts = accounts.fail(error);
    }
    _notify();
  }

  Future<void> refreshAccountUsage() {
    return _accountUsageRefresh ??= _loadAccountUsage().whenComplete(
      () => _accountUsageRefresh = null,
    );
  }

  Future<void> _loadAccountUsage() async {
    lastAccountUsageRefreshStartedAt = DateTime.now().toUtc();
    lastAccountUsageRefreshFinishedAt = null;
    accountUsageRefreshSucceededIds = <String>{};
    accountUsageRefreshFailedIds = <String>{};
    accounts = accounts.begin();
    accountActionError = null;
    _notify();
    try {
      final result = await _repository.refreshAccounts();
      DateTime? latestSample;
      final succeededIds = <String>{};
      final failedIds = <String>{};
      for (final account in result) {
        final sample = account.usageSampleAt;
        if (sample != null &&
            (latestSample == null || sample.isAfter(latestSample))) {
          latestSample = sample;
        }
        final refreshedThisSession =
            sample != null &&
            !sample.toUtc().isBefore(sessionStartedAt.toUtc());
        if (refreshedThisSession) {
          succeededIds.add(account.accountId);
        } else if (account.isActive) {
          failedIds.add(account.accountId);
        }
      }
      accountUsageRefreshSucceededIds = succeededIds;
      accountUsageRefreshFailedIds = failedIds;
      lastAccountUsageRefreshFinishedAt = DateTime.now().toUtc();
      accounts = accounts.succeed(result, sourceSampleAt: latestSample);
      unawaited(
        Future.wait<void>(<Future<void>>[
          refreshOverview(),
          refreshDashboardProjections(),
          refreshCodexLaunchRoute(),
        ]),
      );
    } on Object catch (error) {
      accountActionError = error;
      final currentAccounts = accounts.value ?? const <AccountSummary>[];
      accountUsageRefreshFailedIds = currentAccounts
          .where((account) => account.isActive)
          .map((account) => account.accountId)
          .toSet();
      lastAccountUsageRefreshFinishedAt = DateTime.now().toUtc();
      accounts = accounts.fail(error);
    }
    _notify();
  }

  Future<void> refreshReports({ReportsQuery? query}) {
    if (query != null && query != reportsQuery) {
      reportsQuery = query;
      _reportsRefresh = null;
    }
    return _reportsRefresh ??= _loadReports().whenComplete(
      () => _reportsRefresh = null,
    );
  }

  Future<void> _loadReports() async {
    reports = reports.begin();
    _notify();
    try {
      final result = await _repository.getReports(query: reportsQuery);
      final latestDate = result.daily.isEmpty
          ? null
          : DateTime.tryParse(result.daily.last.date)?.toUtc();
      reports = reports.succeed(result, sourceSampleAt: latestDate);
    } on Object catch (error) {
      reports = reports.fail(error);
    }
    _notify();
  }

  Future<void> refreshApiKeys() {
    return _apiKeysRefresh ??= _loadApiKeys().whenComplete(
      () => _apiKeysRefresh = null,
    );
  }

  Future<void> _loadApiKeys() async {
    apiKeys = apiKeys.begin();
    _notify();
    try {
      apiKeys = apiKeys.succeed(await _repository.listApiKeys());
    } on Object catch (error) {
      apiKeys = apiKeys.fail(error);
    }
    _notify();
  }

  Future<void> refreshApiKeyAnalytics(
    String keyId, {
    bool force = false,
  }) async {
    if (force) {
      final pending = _apiKeyAnalyticsRefresh[keyId];
      if (pending != null) {
        await pending;
      }
      _apiKeyAnalyticsRefresh.remove(keyId);
    }
    await (_apiKeyAnalyticsRefresh[keyId] ??= _loadApiKeyAnalytics(
      keyId,
    ).whenComplete(() => _apiKeyAnalyticsRefresh.remove(keyId)));
  }

  Future<void> _loadApiKeyAnalytics(String keyId) async {
    var section =
        apiKeyAnalytics[keyId] ?? const AsyncSection<ApiKeyAnalytics>();
    section = section.begin();
    apiKeyAnalytics[keyId] = section;
    _notify();
    try {
      final result = await _repository.getApiKeyAnalytics(keyId);
      apiKeyAnalytics[keyId] = section.succeed(
        result,
        sourceSampleAt: result.latestSampleAt,
      );
    } on Object catch (error) {
      apiKeyAnalytics[keyId] = section.fail(error);
    }
    _notify();
  }

  Future<void> refreshModels() {
    return _modelsRefresh ??= _loadModels().whenComplete(
      () => _modelsRefresh = null,
    );
  }

  Future<void> _loadModels() async {
    models = models.begin();
    _notify();
    try {
      models = models.succeed(await _repository.listModels());
    } on Object catch (error) {
      models = models.fail(error);
    }
    _notify();
  }

  Future<void> refreshAutomations() {
    return _automationsRefresh ??= _loadAutomations().whenComplete(
      () => _automationsRefresh = null,
    );
  }

  Future<void> _loadAutomations() async {
    automations = automations.begin();
    _notify();
    try {
      automations = automations.succeed(await _repository.listAutomations());
    } on Object catch (error) {
      automations = automations.fail(error);
    }
    _notify();
  }

  Future<void> refreshAutomationRuns() {
    return _automationRunsRefresh ??= _loadAutomationRuns().whenComplete(
      () => _automationRunsRefresh = null,
    );
  }

  Future<void> _loadAutomationRuns() async {
    automationRuns = automationRuns.begin();
    _notify();
    try {
      final result = await _repository.listAutomationRuns();
      final latest = result.items.isEmpty ? null : result.items.first.startedAt;
      automationRuns = automationRuns.succeed(result, sourceSampleAt: latest);
    } on Object catch (error) {
      automationRuns = automationRuns.fail(error);
    }
    _notify();
  }

  Future<void> refreshSettings() {
    return _settingsRefresh ??= _loadSettings().whenComplete(
      () => _settingsRefresh = null,
    );
  }

  Future<void> _loadSettings() async {
    settings = settings.begin();
    _notify();
    try {
      settings = settings.succeed(await _repository.getSettings());
    } on Object catch (error) {
      settings = settings.fail(error);
    }
    _notify();
  }

  Future<void> refreshUpstreamProxy() {
    return _upstreamProxyRefresh ??= _loadUpstreamProxy().whenComplete(
      () => _upstreamProxyRefresh = null,
    );
  }

  Future<void> _loadUpstreamProxy() async {
    upstreamProxy = upstreamProxy.begin();
    _notify();
    try {
      upstreamProxy = upstreamProxy.succeed(
        await _repository.getUpstreamProxyAdmin(),
      );
    } on Object catch (error) {
      upstreamProxy = upstreamProxy.fail(error);
    }
    _notify();
  }

  Future<void> refreshModelSources() {
    return _modelSourcesRefresh ??= _loadModelSources().whenComplete(
      () => _modelSourcesRefresh = null,
    );
  }

  Future<void> _loadModelSources() async {
    modelSources = modelSources.begin();
    _notify();
    try {
      modelSources = modelSources.succeed(await _repository.getModelSources());
    } on Object catch (error) {
      modelSources = modelSources.fail(error);
    }
    _notify();
  }

  Future<void> refreshFirewall() {
    return _firewallRefresh ??= _loadFirewall().whenComplete(
      () => _firewallRefresh = null,
    );
  }

  Future<void> _loadFirewall() async {
    firewall = firewall.begin();
    _notify();
    try {
      firewall = firewall.succeed(await _repository.getFirewallPolicy());
    } on Object catch (error) {
      firewall = firewall.fail(error);
    }
    _notify();
  }

  Future<void> refreshQuotaPlanner() {
    return _quotaPlannerRefresh ??= _loadQuotaPlanner().whenComplete(
      () => _quotaPlannerRefresh = null,
    );
  }

  Future<void> _loadQuotaPlanner() async {
    quotaPlanner = quotaPlanner.begin();
    _notify();
    try {
      quotaPlanner = quotaPlanner.succeed(
        await _repository.getQuotaPlannerSnapshot(),
      );
    } on Object catch (error) {
      quotaPlanner = quotaPlanner.fail(error);
    }
    _notify();
  }

  Future<void> refreshStickySessions({StickySessionsQuery? query}) {
    if (query != null && query != stickySessionsQuery) {
      stickySessionsQuery = query;
      _stickySessionsRefresh = null;
    }
    return _stickySessionsRefresh ??= _loadStickySessions().whenComplete(
      () => _stickySessionsRefresh = null,
    );
  }

  Future<void> _loadStickySessions() async {
    stickySessions = stickySessions.begin();
    _notify();
    try {
      stickySessions = stickySessions.succeed(
        await _repository.getStickySessions(stickySessionsQuery),
      );
    } on Object catch (error) {
      stickySessions = stickySessions.fail(error);
    }
    _notify();
  }

  Future<void> refreshCodexIntegration() {
    return _codexIntegrationRefresh ??= _loadCodexIntegration().whenComplete(
      () => _codexIntegrationRefresh = null,
    );
  }

  Future<void> _loadCodexIntegration() async {
    codexIntegration = codexIntegration.begin();
    _notify();
    try {
      codexIntegration = codexIntegration.succeed(
        await _repository.getCodexIntegrationStatus(),
      );
    } on Object catch (error) {
      codexIntegration = codexIntegration.fail(error);
    }
    _notify();
  }

  Future<void> refreshCodexInstallation() {
    return _codexInstallationRefresh ??= _loadCodexInstallation().whenComplete(
      () => _codexInstallationRefresh = null,
    );
  }

  Future<void> _loadCodexInstallation() async {
    codexInstallation = codexInstallation.begin();
    _notify();
    try {
      final result = await _codexInstallationDiscovery.discover();
      codexInstallation = codexInstallation.succeed(result);
    } on Object catch (error) {
      codexInstallation = codexInstallation.fail(error);
    }
    _notify();
  }

  Future<void> refreshCodexProfiles() {
    return _codexProfilesRefresh ??= _loadCodexProfiles().whenComplete(
      () => _codexProfilesRefresh = null,
    );
  }

  Future<void> _loadCodexProfiles() async {
    codexProfiles = codexProfiles.begin();
    _notify();
    try {
      codexProfiles = codexProfiles.succeed(
        await _repository.getCodexProfiles(),
      );
    } on Object catch (error) {
      codexProfiles = codexProfiles.fail(error);
    }
    _notify();
  }

  Future<void> refreshCodexLaunchRoute() {
    return _codexLaunchRouteRefresh ??= _loadCodexLaunchRoute().whenComplete(
      () => _codexLaunchRouteRefresh = null,
    );
  }

  Future<void> _loadCodexLaunchRoute() async {
    codexLaunchRoute = codexLaunchRoute.begin();
    _notify();
    try {
      final result = await _repository.getCodexLaunchRoute();
      codexLaunchRoute = codexLaunchRoute.succeed(
        result,
        sourceSampleAt: result.sampledAt,
      );
    } on Object catch (error) {
      codexLaunchRoute = codexLaunchRoute.fail(error);
    }
    _notify();
  }

  List<AccountSummary> orderedAccounts(Iterable<AccountSummary> source) =>
      orderAccountsByRemainingUsage(source, order: accountRemainingUsageOrder);

  void setAccountRemainingUsageOrder(AccountRemainingUsageOrder next) {
    if (accountRemainingUsageOrder == next) {
      return;
    }
    accountRemainingUsageOrder = next;
    _notify();
  }

  void selectManualCodexAccount(String? accountId) {
    final normalized = accountId?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    if (selectedManualCodexAccountId == next) {
      return;
    }
    selectedManualCodexAccountId = next;
    codexLaunchActionError = null;
    _notify();
  }

  void selectDestination(AppDestination next, {bool refresh = true}) {
    if (destination == next) {
      return;
    }
    performanceProbe?.markCachedNavigationAfterNextFrame(next.name);
    destination = next;
    _notify();
    if (refresh) {
      unawaited(_loadDestination(next));
    }
  }

  void _installSyntheticPerformanceAccounts() {
    final rowCount = performanceProbe?.syntheticAccountRows;
    if (rowCount == null) {
      return;
    }
    final sampleAt = DateTime.now().toUtc();
    final rows = List<AccountSummary>.generate(rowCount, (index) {
      final suffix = index.toString().padLeft(4, '0');
      return AccountSummary(
        accountId: 'performance-fixture-$suffix',
        email: 'fixture-$suffix@example.invalid',
        displayName: 'Performance account $suffix',
        planType: 'fixture',
        routingPolicy: 'normal',
        status: 'active',
        securityWorkAuthorized: false,
        usage: AccountUsage(primaryRemainingPercent: 100 - (index % 100)),
        lastRefreshAt: sampleAt,
        requestUsage: null,
        isEmailDuplicate: false,
        availableResetCredits: 0,
      );
    });
    accounts = accounts.succeed(rows, sourceSampleAt: sampleAt);
    selectDestination(AppDestination.accounts, refresh: false);
  }

  Future<void> _loadDestination(AppDestination next) async {
    switch (next) {
      case AppDestination.pulse:
        return;
      case AppDestination.reports:
        await Future.wait<void>(<Future<void>>[
          refreshReports(),
          refreshOverview(),
          refreshDashboardProjections(),
          refreshRequestLogs(),
          refreshRequestLogOptions(),
          refreshCodexLaunchRoute(),
        ]);
        return;
      case AppDestination.accounts:
        await refreshAccounts();
        if (canWrite && performanceProbe?.syntheticAccountRows == null) {
          // Keep cached-first navigation fast, then join the same single-flight
          // live refresh used by startup and the explicit Refresh all action.
          unawaited(refreshAccountUsage());
        }
        return;
      case AppDestination.apis:
        await Future.wait<void>(<Future<void>>[
          refreshApiKeys(),
          refreshModels(),
        ]);
        return;
      case AppDestination.settings:
        await Future.wait<void>(<Future<void>>[
          refreshSettings(),
          refreshCodexIntegration(),
          refreshCodexLaunchRoute(),
          if (_managedAppServerEnabled) refreshCodexInstallation(),
          if (_managedAppServerEnabled) refreshCodexProfiles(),
        ]);
        return;
      case AppDestination.automations:
        await Future.wait<void>(<Future<void>>[
          refreshAutomations(),
          refreshAutomationRuns(),
          refreshModels(),
        ]);
        return;
    }
  }

  Future<void> refreshCurrentDestination() async {
    await _loadDestination(destination);
    if (destination == AppDestination.settings) {
      await Future.wait<void>(<Future<void>>[
        if (upstreamProxy.value != null) refreshUpstreamProxy(),
        if (modelSources.value != null) refreshModelSources(),
        if (firewall.value != null) refreshFirewall(),
        if (quotaPlanner.value != null) refreshQuotaPlanner(),
        if (stickySessions.value != null) refreshStickySessions(),
      ]);
    }
  }

  Future<void> pauseAccount(String accountId) async {
    await _runAccountMutation(
      accountId,
      () => _repository.pauseAccount(accountId),
    );
  }

  Future<void> reactivateAccount(String accountId) async {
    await _runAccountMutation(
      accountId,
      () => _repository.reactivateAccount(accountId),
    );
  }

  Future<bool> importAccountJson(String rawJson) async {
    if (!canWrite || accountGlobalActionBusy) {
      return false;
    }
    accountGlobalActionBusy = true;
    accountActionError = null;
    _notify();
    try {
      await _repository.importAccountJson(rawJson);
      await _reloadAccountsAndOverviewAfterMutation();
      return true;
    } on Object catch (error) {
      accountActionError = error;
      return false;
    } finally {
      accountGlobalActionBusy = false;
      _notify();
    }
  }

  Future<void> setAccountAlias(String accountId, String? alias) async {
    await _runAccountMutation(
      accountId,
      () => _repository.setAccountAlias(accountId, alias),
    );
  }

  Future<void> updateAccountSecurityAuthorization(
    String accountId,
    bool authorized,
  ) async {
    await _runAccountMutation(
      accountId,
      () =>
          _repository.updateAccountSecurityAuthorization(accountId, authorized),
    );
  }

  Future<void> updateAccountLimitWarmup(String accountId, bool enabled) async {
    await _runAccountMutation(
      accountId,
      () => _repository.updateAccountLimitWarmup(accountId, enabled),
    );
  }

  Future<void> updateAccountRoutingPolicy(
    String accountId,
    String policy,
  ) async {
    await _runAccountMutation(
      accountId,
      () => _repository.updateAccountRoutingPolicy(accountId, policy),
    );
  }

  Future<void> deleteAccount(
    String accountId, {
    required bool deleteHistory,
  }) async {
    await _runAccountMutation(
      accountId,
      () => _repository.deleteAccount(accountId, deleteHistory: deleteHistory),
    );
  }

  Future<AccountProbeResult?> probeAccount(String accountId, {String? model}) {
    return _runAccountResult(
      accountId,
      () => _repository.probeAccount(accountId, model: model),
    );
  }

  Future<AccountUsageResetResult?> consumeAccountUsageResetCredit(
    String accountId,
  ) {
    final requestId =
        'native-${DateTime.now().microsecondsSinceEpoch}-${accountId.hashCode.abs()}';
    return _runAccountResult(
      accountId,
      () => _repository.consumeAccountUsageResetCredit(
        accountId,
        redeemRequestId: requestId,
      ),
    );
  }

  Future<AccountTrends?> getAccountTrends(String accountId) async {
    try {
      return await _repository.getAccountTrends(accountId);
    } on Object catch (error) {
      accountActionError = error;
      _notify();
      return null;
    }
  }

  Future<AccountUsageResetCredits?> getAccountUsageResetCredits(
    String accountId,
  ) async {
    try {
      return await _repository.getAccountUsageResetCredits(accountId);
    } on Object catch (error) {
      accountActionError = error;
      _notify();
      return null;
    }
  }

  Future<OauthStartResult?> startOauth({
    String? forceMethod,
    String? accountId,
  }) async {
    if (!canWrite || accountGlobalActionBusy) {
      return null;
    }
    accountGlobalActionBusy = true;
    accountActionError = null;
    _notify();
    try {
      return await _repository.startOauth(
        forceMethod: forceMethod,
        accountId: accountId,
      );
    } on Object catch (error) {
      accountActionError = error;
      return null;
    } finally {
      accountGlobalActionBusy = false;
      _notify();
    }
  }

  Future<OauthStatusResult?> getOauthStatus({String? flowId}) async {
    try {
      return await _repository.getOauthStatus(flowId: flowId);
    } on Object catch (error) {
      accountActionError = error;
      _notify();
      return null;
    }
  }

  Future<OauthStatusResult?> completeOauth(OauthStartResult flow) async {
    if (!canWrite || accountGlobalActionBusy) {
      return null;
    }
    accountGlobalActionBusy = true;
    accountActionError = null;
    _notify();
    try {
      final result = await _repository.completeOauth(flow);
      if (result.succeeded) {
        await _reloadAccountsAndOverviewAfterMutation();
      }
      return result;
    } on Object catch (error) {
      accountActionError = error;
      return null;
    } finally {
      accountGlobalActionBusy = false;
      _notify();
    }
  }

  Future<OauthStatusResult?> submitManualOauthCallback(
    OauthStartResult flow,
    String callbackUrl,
  ) async {
    if (!canWrite || accountGlobalActionBusy) {
      return null;
    }
    accountGlobalActionBusy = true;
    accountActionError = null;
    _notify();
    try {
      final result = await _repository.submitManualOauthCallback(
        callbackUrl,
        flowId: flow.flowId,
      );
      if (result.succeeded) {
        await _reloadAccountsAndOverviewAfterMutation();
      }
      return result;
    } on Object catch (error) {
      accountActionError = error;
      return null;
    } finally {
      accountGlobalActionBusy = false;
      _notify();
    }
  }

  Future<void> _reloadAccountsAndOverviewAfterMutation() async {
    final pending = <Future<void>?>[
      _accountsRefresh,
      _overviewRefresh,
      _projectionsRefresh,
    ].whereType<Future<void>>().toList(growable: false);
    if (pending.isNotEmpty) {
      await Future.wait<void>(pending);
    }
    _accountsRefresh = null;
    _overviewRefresh = null;
    _projectionsRefresh = null;
    await Future.wait<void>(<Future<void>>[
      refreshAccounts(),
      refreshOverview(),
      refreshDashboardProjections(),
    ]);
  }

  Future<void> _reloadApiKeysAfterMutation() async {
    if (_apiKeysRefresh != null) {
      await _apiKeysRefresh;
    }
    _apiKeysRefresh = null;
    await refreshApiKeys();
  }

  Future<void> _reloadAutomationsAfterMutation({
    bool includeRuns = false,
  }) async {
    final pending = <Future<void>?>[
      _automationsRefresh,
      if (includeRuns) _automationRunsRefresh,
    ].whereType<Future<void>>().toList(growable: false);
    if (pending.isNotEmpty) {
      await Future.wait<void>(pending);
    }
    _automationsRefresh = null;
    if (includeRuns) {
      _automationRunsRefresh = null;
    }
    await Future.wait<void>(<Future<void>>[
      refreshAutomations(),
      if (includeRuns) refreshAutomationRuns(),
    ]);
  }

  Future<void> _reloadProxyAfterMutation({bool includeAccounts = false}) async {
    final pending = <Future<void>?>[
      _upstreamProxyRefresh,
      if (includeAccounts) _accountsRefresh,
    ].whereType<Future<void>>().toList(growable: false);
    if (pending.isNotEmpty) {
      await Future.wait<void>(pending);
    }
    _upstreamProxyRefresh = null;
    if (includeAccounts) {
      _accountsRefresh = null;
    }
    await Future.wait<void>(<Future<void>>[
      refreshUpstreamProxy(),
      if (includeAccounts) refreshAccounts(),
    ]);
  }

  Future<void> _runAccountMutation(
    String accountId,
    Future<void> Function() mutation,
  ) async {
    if (!canWrite || mutatingAccountIds.contains(accountId)) {
      return;
    }
    mutatingAccountIds.add(accountId);
    accountActionError = null;
    _notify();
    try {
      await mutation();
      await _reloadAccountsAndOverviewAfterMutation();
    } on Object catch (error) {
      accountActionError = error;
    } finally {
      mutatingAccountIds.remove(accountId);
      _notify();
    }
  }

  Future<T?> _runAccountResult<T>(
    String accountId,
    Future<T> Function() mutation,
  ) async {
    if (!canWrite || mutatingAccountIds.contains(accountId)) {
      return null;
    }
    mutatingAccountIds.add(accountId);
    accountActionError = null;
    _notify();
    try {
      final result = await mutation();
      await _reloadAccountsAndOverviewAfterMutation();
      return result;
    } on Object catch (error) {
      accountActionError = error;
      return null;
    } finally {
      mutatingAccountIds.remove(accountId);
      _notify();
    }
  }

  Future<ApiKeyCreateResult?> createApiKey(Map<String, Object?> payload) async {
    if (!canWrite || apiKeyActionBusy) {
      return null;
    }
    apiKeyActionBusy = true;
    apiKeyActionError = null;
    _notify();
    try {
      final result = await _repository.createApiKey(payload);
      await _reloadApiKeysAfterMutation();
      return result;
    } on Object catch (error) {
      apiKeyActionError = error;
      return null;
    } finally {
      apiKeyActionBusy = false;
      _notify();
    }
  }

  Future<bool> updateApiKey(String keyId, Map<String, Object?> payload) async {
    if (!canWrite || mutatingApiKeyIds.contains(keyId)) {
      return false;
    }
    mutatingApiKeyIds.add(keyId);
    apiKeyActionError = null;
    _notify();
    try {
      await _repository.updateApiKey(keyId, payload);
      apiKeyAnalytics.remove(keyId);
      await _reloadApiKeysAfterMutation();
      return true;
    } on Object catch (error) {
      apiKeyActionError = error;
      return false;
    } finally {
      mutatingApiKeyIds.remove(keyId);
      _notify();
    }
  }

  Future<bool> deleteApiKey(String keyId) async {
    if (!canWrite || mutatingApiKeyIds.contains(keyId)) {
      return false;
    }
    mutatingApiKeyIds.add(keyId);
    apiKeyActionError = null;
    _notify();
    try {
      await _repository.deleteApiKey(keyId);
      apiKeyAnalytics.remove(keyId);
      await _reloadApiKeysAfterMutation();
      return true;
    } on Object catch (error) {
      apiKeyActionError = error;
      return false;
    } finally {
      mutatingApiKeyIds.remove(keyId);
      _notify();
    }
  }

  Future<ApiKeyCreateResult?> regenerateApiKey(String keyId) async {
    if (!canWrite || mutatingApiKeyIds.contains(keyId)) {
      return null;
    }
    mutatingApiKeyIds.add(keyId);
    apiKeyActionError = null;
    _notify();
    try {
      final result = await _repository.regenerateApiKey(keyId);
      await _reloadApiKeysAfterMutation();
      return result;
    } on Object catch (error) {
      apiKeyActionError = error;
      return null;
    } finally {
      mutatingApiKeyIds.remove(keyId);
      _notify();
    }
  }

  Future<bool> updateSettings(Map<String, Object?> changes) async {
    final current = settings.value;
    if (!canWrite || settingsActionBusy || current == null || changes.isEmpty) {
      return false;
    }
    settingsActionBusy = true;
    settingsActionError = null;
    _notify();
    try {
      settings = settings.succeed(
        await _repository.updateSettings(current, changes),
      );
      return true;
    } on Object catch (error) {
      settingsActionError = error;
      if (error is ApiException && error.statusCode == 409) {
        if (_settingsRefresh != null) {
          await _settingsRefresh;
        }
        _settingsRefresh = null;
        await refreshSettings();
      }
      return false;
    } finally {
      settingsActionBusy = false;
      _notify();
    }
  }

  Future<StorageCleanupPreview?> previewStorageCleanup({
    required List<StorageCleanupCategory> categories,
    required int olderThanDays,
  }) async {
    if (!canWrite || storageCleanupActionBusy || categories.isEmpty) {
      return null;
    }
    storageCleanupActionBusy = true;
    storageCleanupActionError = null;
    lastStorageCleanupResult = null;
    _notify();
    try {
      final preview = await _repository.previewStorageCleanup(
        categories: categories,
        olderThanDays: olderThanDays,
      );
      storageCleanupPreview = preview;
      return preview;
    } on Object catch (error) {
      storageCleanupActionError = error;
      storageCleanupPreview = null;
      return null;
    } finally {
      storageCleanupActionBusy = false;
      _notify();
    }
  }

  Future<StorageCleanupResult?> applyStorageCleanup({
    required List<StorageCleanupCategory> categories,
    required int olderThanDays,
    required String confirmationToken,
  }) async {
    if (!canWrite || storageCleanupActionBusy) {
      return null;
    }
    storageCleanupActionBusy = true;
    storageCleanupActionError = null;
    _notify();
    try {
      final result = await _repository.applyStorageCleanup(
        categories: categories,
        olderThanDays: olderThanDays,
        confirmationToken: confirmationToken,
      );
      lastStorageCleanupResult = result;
      storageCleanupPreview = null;
      return result;
    } on Object catch (error) {
      storageCleanupActionError = error;
      return null;
    } finally {
      storageCleanupActionBusy = false;
      _notify();
    }
  }

  Future<CodexIntegrationMutation?> setCodexManagedRoutingEnabled(
    bool enabled,
  ) async {
    final current = codexIntegration.value;
    if (!canWrite || codexIntegrationActionBusy || current == null) {
      return null;
    }
    codexIntegrationActionBusy = true;
    codexIntegrationActionError = null;
    _notify();
    try {
      if (enabled) {
        final capability = await _codexDesktopLauncher
            .inspectManagedCapability();
        if (!capability.supported) {
          throw StateError(
            capability.reason ??
                'This installed Codex build does not support safe managed launch.',
          );
        }
      }
      final result = await _repository.setCodexManagedRoutingEnabled(
        current,
        enabled: enabled,
      );
      codexIntegration = codexIntegration.succeed(result.status);
      codexModeChangeAffectsNextLaunch = await _codexDesktopLauncher
          .isRunning();
      return result;
    } on Object catch (error) {
      codexIntegrationActionError = error;
      if (error is ApiException && error.statusCode == 409) {
        await _reloadCodexIntegrationAfterConflict();
      }
      return null;
    } finally {
      codexIntegrationActionBusy = false;
      _notify();
    }
  }

  Future<void> _reloadCodexIntegrationAfterConflict() async {
    if (_codexIntegrationRefresh != null) {
      await _codexIntegrationRefresh;
    }
    _codexIntegrationRefresh = null;
    await refreshCodexIntegration();
  }

  CodexProfileDefinition? get activeCodexProfile =>
      codexProfiles.value?.activeProfile;

  CodexAppServerRuntime? get codexAppServerRuntime =>
      _codexAppServerSupervisor.runtime;

  Future<CodexProfileSwitchOutcome?> switchCodexProfile(
    String profileId, {
    bool confirmed = false,
  }) async {
    final targetId = profileId.trim();
    if (!_managedAppServerEnabled ||
        targetId.isEmpty ||
        codexProfileActionBusy) {
      return null;
    }
    codexProfileActionBusy = true;
    codexProfileActionError = null;
    lastCodexProfileSwitchOutcome = null;
    _notify();

    CodexProfileRegistry? activatedRegistry;
    CodexProfileDefinition? previousProfile;
    var transactionStarted = false;
    var liveRootCount = 0;
    var liveDescendantCount = 0;
    try {
      final prerequisites = await _codexProfilePrerequisites();
      final registry = prerequisites.registry;
      previousProfile = registry.activeProfile;
      final target = registry.profiles
          .where((profile) => profile.id == targetId)
          .firstOrNull;
      if (target == null) {
        throw StateError('Codex profile was not found: $targetId');
      }
      if (target.id == previousProfile.id) {
        final result = CodexProfileSwitchOutcome(
          disposition: CodexProfileSwitchDisposition.unchanged,
          previousProfileId: previousProfile.id,
          targetProfileId: target.id,
          liveRootCount: 0,
          liveDescendantCount: 0,
        );
        lastCodexProfileSwitchOutcome = result;
        return result;
      }

      final currentRuntime = await _startCodexProfileRuntime(
        previousProfile,
        prerequisites.installation,
        prerequisites.integration,
      );
      final lifecycle = CodexTaskLifecycleService(currentRuntime.client);
      final preflight = await lifecycle.preflight();
      lastCodexProfileSwitchPreflight = preflight;
      liveRootCount = preflight.liveRootCount;
      liveDescendantCount = preflight.liveDescendantCount;
      if (liveRootCount > 0 && !confirmed) {
        final result = CodexProfileSwitchOutcome(
          disposition: CodexProfileSwitchDisposition.confirmationRequired,
          previousProfileId: previousProfile.id,
          targetProfileId: target.id,
          liveRootCount: liveRootCount,
          liveDescendantCount: liveDescendantCount,
        );
        lastCodexProfileSwitchOutcome = result;
        return result;
      }

      if (confirmed) {
        for (final group in preflight.liveGroups) {
          await lifecycle.pause(group.sessionId);
        }
      }

      transactionStarted = true;
      if (await _codexDesktopLauncher.isRunning()) {
        final stopped = await _codexDesktopLauncher.stopRunningForRestart();
        if (!stopped || await _codexDesktopLauncher.isRunning()) {
          throw StateError(
            'Codex did not fully close, so the profile switch was cancelled.',
          );
        }
      }
      await _stopCodexProfileRuntime(previousProfile);

      activatedRegistry = await _repository.activateCodexProfile(
        registry,
        target.id,
      );
      codexProfiles = codexProfiles.succeed(activatedRegistry);
      _notify();

      final targetRuntime = await _startCodexProfileRuntime(
        target,
        prerequisites.installation,
        prerequisites.integration,
      );
      await _launchCodexProfileDesktop(
        target,
        targetRuntime,
        prerequisites.integration,
      );
      final result = CodexProfileSwitchOutcome(
        disposition: CodexProfileSwitchDisposition.switched,
        previousProfileId: previousProfile.id,
        targetProfileId: target.id,
        liveRootCount: liveRootCount,
        liveDescendantCount: liveDescendantCount,
      );
      lastCodexProfileSwitchOutcome = result;
      return result;
    } on Object catch (error) {
      codexProfileActionError = error;
      if (!transactionStarted || previousProfile == null) {
        final result = CodexProfileSwitchOutcome(
          disposition: CodexProfileSwitchDisposition.failed,
          previousProfileId: previousProfile?.id ?? 'unknown',
          targetProfileId: targetId,
          liveRootCount: liveRootCount,
          liveDescendantCount: liveDescendantCount,
          error: error,
        );
        lastCodexProfileSwitchOutcome = result;
        return result;
      }

      Object? rollbackError;
      try {
        await _codexAppServerSupervisor.stop();
        await _oxBridgeSupervisor.stop();
        var rollbackRegistry = activatedRegistry;
        if (rollbackRegistry != null &&
            rollbackRegistry.activeProfileId != previousProfile.id) {
          rollbackRegistry = await _repository.activateCodexProfile(
            rollbackRegistry,
            previousProfile.id,
          );
          codexProfiles = codexProfiles.succeed(rollbackRegistry);
        }
        final prerequisites = await _codexProfilePrerequisites();
        final rollbackRuntime = await _startCodexProfileRuntime(
          previousProfile,
          prerequisites.installation,
          prerequisites.integration,
        );
        await _launchCodexProfileDesktop(
          previousProfile,
          rollbackRuntime,
          prerequisites.integration,
        );
      } on Object catch (rollbackFailure) {
        rollbackError = rollbackFailure;
      }
      final result = CodexProfileSwitchOutcome(
        disposition: rollbackError == null
            ? CodexProfileSwitchDisposition.rolledBack
            : CodexProfileSwitchDisposition.failed,
        previousProfileId: previousProfile.id,
        targetProfileId: targetId,
        liveRootCount: liveRootCount,
        liveDescendantCount: liveDescendantCount,
        error: error,
        rollbackError: rollbackError,
      );
      lastCodexProfileSwitchOutcome = result;
      return result;
    } finally {
      codexProfileActionBusy = false;
      _notify();
    }
  }

  Future<CodexTaskPauseResult?> pauseCodexTask(String sessionId) async {
    final normalized = sessionId.trim();
    final result = await _runCodexTaskAction(
      sessionId,
      (lifecycle) => lifecycle.pause(sessionId),
    );
    if (result != null) {
      pausedCodexTaskIds.add(normalized);
      if (result.requiresContinuation) {
        codexTaskContinuationRequiredIds.add(normalized);
      } else {
        codexTaskContinuationRequiredIds.remove(normalized);
      }
      _notify();
    }
    return result;
  }

  Future<RuntimeControlSnapshot> getRuntimeControlSnapshot() {
    return _repository.getRuntimeControlSnapshot();
  }

  Future<RuntimeTaskActionResult?> controlRuntimeTask(
    AgentRuntime runtime,
    String nativeId,
    String action,
  ) async {
    final normalizedId = nativeId.trim();
    final key = '${runtime.name}:$normalizedId';
    if (!canWrite ||
        runtime == AgentRuntime.codex ||
        normalizedId.isEmpty ||
        mutatingRuntimeTaskIds.contains(key)) {
      return null;
    }
    mutatingRuntimeTaskIds.add(key);
    runtimeTaskActionError = null;
    _notify();
    try {
      return await _repository.controlRuntimeTask(
        runtime: runtime,
        nativeId: normalizedId,
        action: action,
      );
    } on Object catch (error) {
      runtimeTaskActionError = error;
      return null;
    } finally {
      mutatingRuntimeTaskIds.remove(key);
      _notify();
    }
  }

  Future<CodexTaskResumeResult?> resumeCodexTask(String sessionId) async {
    final normalized = sessionId.trim();
    final result = await _runCodexTaskAction(
      sessionId,
      (lifecycle) => lifecycle.resume(sessionId),
    );
    if (result != null) {
      if (result.disposition ==
          CodexTaskResumeDisposition.continuationRequired) {
        pausedCodexTaskIds.add(normalized);
        codexTaskContinuationRequiredIds.add(normalized);
      } else {
        pausedCodexTaskIds.remove(normalized);
        codexTaskContinuationRequiredIds.remove(normalized);
      }
      _notify();
    }
    return result;
  }

  Future<CodexTaskResumeResult?> continueCodexTask(String sessionId) async {
    final normalized = sessionId.trim();
    final result = await _runCodexTaskAction(
      sessionId,
      (lifecycle) => lifecycle.continueTask(sessionId),
    );
    if (result != null) {
      pausedCodexTaskIds.remove(normalized);
      codexTaskContinuationRequiredIds.remove(normalized);
      _notify();
    }
    return result;
  }

  Future<T?> _runCodexTaskAction<T>(
    String sessionId,
    Future<T> Function(CodexTaskLifecycleService lifecycle) action,
  ) async {
    final normalized = sessionId.trim();
    if (!_managedAppServerEnabled ||
        normalized.isEmpty ||
        mutatingCodexTaskIds.contains(normalized)) {
      return null;
    }
    mutatingCodexTaskIds.add(normalized);
    codexTaskActionError = null;
    _notify();
    try {
      final prerequisites = await _codexProfilePrerequisites();
      final runtime = await _startCodexProfileRuntime(
        prerequisites.registry.activeProfile,
        prerequisites.installation,
        prerequisites.integration,
      );
      return await action(CodexTaskLifecycleService(runtime.client));
    } on Object catch (error) {
      codexTaskActionError = error;
      return null;
    } finally {
      mutatingCodexTaskIds.remove(normalized);
      _notify();
    }
  }

  Future<
    ({
      CodexProfileRegistry registry,
      CodexInstallation installation,
      CodexIntegrationStatus integration,
    })
  >
  _codexProfilePrerequisites() async {
    await Future.wait<void>(<Future<void>>[
      if (codexProfiles.value == null) refreshCodexProfiles(),
      if (codexInstallation.value == null) refreshCodexInstallation(),
      if (codexIntegration.value == null) refreshCodexIntegration(),
    ]);
    final registry = codexProfiles.value;
    final installation = codexInstallation.value;
    final integration = codexIntegration.value;
    if (registry == null) {
      throw StateError(
        'Codex profiles are unavailable: ${codexProfiles.error ?? 'unknown error'}',
      );
    }
    if (installation == null) {
      throw StateError(
        'Codex installation discovery failed: ${codexInstallation.error ?? 'unknown error'}',
      );
    }
    if (!installation.supportsManagedProfiles) {
      throw StateError(
        'The installed Codex build does not expose the managed WebSocket/profile capabilities.',
      );
    }
    if (integration == null) {
      throw StateError(
        'OpenHUB managed route is unavailable: ${codexIntegration.error ?? 'unknown error'}',
      );
    }
    return (
      registry: registry,
      installation: installation,
      integration: integration,
    );
  }

  Future<CodexAppServerRuntime> _startCodexProfileRuntime(
    CodexProfileDefinition profile,
    CodexInstallation installation,
    CodexIntegrationStatus integration,
  ) async {
    final existing = _codexAppServerSupervisor.runtime;
    if (existing != null) {
      if (existing.profileId == profile.id && !existing.client.isClosed) {
        return existing;
      }
      throw StateError(
        'A different Codex profile runtime is still active; stop it before switching.',
      );
    }
    final managedBaseUrl = Uri.tryParse(integration.managedBaseUrl);
    if (managedBaseUrl == null) {
      throw StateError('The managed Codex route URL is invalid.');
    }
    final plan = await _codexProfileRuntimePlanner.build(
      profile: profile,
      installation: installation,
      managedOpenAiBaseUrl: managedBaseUrl,
    );
    if (profile.kind == 'ox') {
      final bridgeScript = plan.bridgeScript;
      final providerBaseUrl = Uri.tryParse(profile.baseUrl ?? '');
      if (bridgeScript == null || providerBaseUrl == null) {
        throw StateError('The Ox profile package is incomplete.');
      }
      final bridge = await _oxBridgeSupervisor.start(
        bridgeScript: bridgeScript,
        canonicalCodexHome: installation.canonicalCodexHome,
        providerBaseUrl: providerBaseUrl,
      );
      oxBridgeHealth = bridge.health;
      _notify();
    }
    return _codexAppServerSupervisor.start(plan.appServerOptions);
  }

  Future<void> _stopCodexProfileRuntime(
    CodexProfileDefinition previousProfile,
  ) async {
    await _codexAppServerSupervisor.stop();
    if (previousProfile.kind == 'ox') {
      await _oxBridgeSupervisor.stop();
      oxBridgeHealth = null;
    }
  }

  Future<void> _launchCodexProfileDesktop(
    CodexProfileDefinition profile,
    CodexAppServerRuntime runtime,
    CodexIntegrationStatus integration,
  ) async {
    final managedBaseUrl = profile.kind == 'openai_pool'
        ? Uri.tryParse(integration.managedBaseUrl)
        : null;
    final launch = await _codexDesktopLauncher.launch(
      managedBaseUrl: managedBaseUrl,
      appServerWebSocketUrl: runtime.endpoint,
    );
    if (!launch.launched || !launch.managed) {
      throw StateError(
        'Windows did not confirm that Codex adopted the selected profile runtime.',
      );
    }
  }

  Future<CodexManagedLaunchOutcome?> openCodex({String? manualAccountId}) {
    final pending = _codexManagedLaunch;
    if (pending != null) {
      return pending;
    }
    late final Future<CodexManagedLaunchOutcome?> operation;
    operation = _openCodex(manualAccountId: manualAccountId).whenComplete(() {
      if (identical(_codexManagedLaunch, operation)) {
        _codexManagedLaunch = null;
      }
    });
    _codexManagedLaunch = operation;
    return operation;
  }

  Future<CodexManagedLaunchOutcome?> restartCodex({String? manualAccountId}) {
    final pending = _codexManagedLaunch;
    if (pending != null) {
      return pending;
    }
    late final Future<CodexManagedLaunchOutcome?> operation;
    operation = _restartCodex(manualAccountId: manualAccountId).whenComplete(
      () {
        if (identical(_codexManagedLaunch, operation)) {
          _codexManagedLaunch = null;
        }
      },
    );
    _codexManagedLaunch = operation;
    return operation;
  }

  Future<CodexManagedLaunchOutcome?> _restartCodex({
    required String? manualAccountId,
  }) async {
    codexLaunchActionBusy = true;
    codexLaunchActionError = null;
    _notify();
    try {
      final stopped = await _codexDesktopLauncher.stopRunningForRestart();
      if (!stopped) {
        throw StateError(
          'Codex did not fully exit, so the selected account route was not applied.',
        );
      }
    } on Object catch (error) {
      codexLaunchActionError = error;
      return null;
    } finally {
      codexLaunchActionBusy = false;
      _notify();
    }
    return _openCodex(manualAccountId: manualAccountId);
  }

  Future<CodexManagedLaunchOutcome?> _openCodex({
    required String? manualAccountId,
  }) async {
    codexLaunchActionBusy = true;
    codexLaunchActionError = null;
    lastCodexLaunchPreparation = null;
    _notify();
    try {
      var current = codexLaunchRoute.value;
      if (_managedAppServerEnabled) {
        final prerequisites = await _codexProfilePrerequisites();
        final activeProfile = prerequisites.registry.activeProfile;
        if (activeProfile.kind != 'openai_pool') {
          if (current == null) {
            await refreshCodexLaunchRoute();
            current = codexLaunchRoute.value;
          }
          if (current == null) {
            throw StateError('The Codex launch route is unavailable.');
          }
          final running = await _codexDesktopLauncher.isRunning();
          if (running && await _codexDesktopLauncher.focusRunning()) {
            return CodexManagedLaunchOutcome(
              disposition: CodexManagedLaunchDisposition.alreadyRunning,
              route: current,
            );
          }
          if (running) {
            throw StateError(
              'Codex is still running in the background. Fully quit it before attaching the ${activeProfile.label} profile.',
            );
          }
          final runtime = await _startCodexProfileRuntime(
            activeProfile,
            prerequisites.installation,
            prerequisites.integration,
          );
          await _launchCodexProfileDesktop(
            activeProfile,
            runtime,
            prerequisites.integration,
          );
          codexModeChangeAffectsNextLaunch = false;
          return CodexManagedLaunchOutcome(
            disposition: CodexManagedLaunchDisposition.launchedManaged,
            route: current,
          );
        }
      }
      final codexProcessRunning = await _codexDesktopLauncher.isRunning();
      if (codexProcessRunning && await _codexDesktopLauncher.focusRunning()) {
        if (current == null) {
          await refreshCodexLaunchRoute();
          current = codexLaunchRoute.value;
        }
        if (current == null) {
          throw StateError(
            'Codex is already running, but its managed route status is unavailable.',
          );
        }
        return CodexManagedLaunchOutcome(
          disposition: CodexManagedLaunchDisposition.alreadyRunning,
          route: current,
        );
      }

      await Future.wait<void>(<Future<void>>[
        if (codexIntegration.value == null) refreshCodexIntegration(),
        if (current == null) refreshCodexLaunchRoute(),
      ]);
      current = codexLaunchRoute.value;
      final integration = codexIntegration.value;
      if (integration == null) {
        throw StateError(
          'OpenHUB launch mode could not be loaded: ${codexIntegration.error ?? 'unknown error'}',
        );
      }
      if (current == null) {
        throw StateError('The Codex launch route is unavailable.');
      }

      final selectedAccountId = manualAccountId?.trim();
      final manualLaunch =
          selectedAccountId != null && selectedAccountId.isNotEmpty;
      if (!integration.enabled && !manualLaunch) {
        final launch = await _codexDesktopLauncher.launch();
        if (launch.alreadyRunning) {
          return CodexManagedLaunchOutcome(
            disposition: CodexManagedLaunchDisposition.alreadyRunning,
            route: current,
          );
        }
        if (!launch.launched || launch.managed) {
          throw StateError('Windows did not confirm a normal Codex launch.');
        }
        codexModeChangeAffectsNextLaunch = false;
        return CodexManagedLaunchOutcome(
          disposition: CodexManagedLaunchDisposition.launchedNormal,
          route: current,
        );
      }

      if (codexProcessRunning) {
        throw StateError(
          'Codex is still running in the background. Fully quit Codex, then retry so the selected account route can be applied to the new process.',
        );
      }

      if (!canWrite) {
        throw StateError(
          'Managed Codex launch requires write permission in the local dashboard session.',
        );
      }
      final capability = await _codexDesktopLauncher.inspectManagedCapability();
      if (!capability.supported) {
        throw StateError(
          capability.reason ??
              'This installed Codex build does not support safe managed launch.',
        );
      }

      final preparation = await _repository.prepareCodexLaunch(
        current,
        accountId: manualLaunch ? selectedAccountId : null,
      );
      lastCodexLaunchPreparation = preparation;
      codexLaunchRoute = codexLaunchRoute.succeed(
        preparation.route,
        sourceSampleAt: preparation.route.sampledAt,
      );
      _notify();
      if (!preparation.readyToLaunch || !preparation.route.prepared) {
        return CodexManagedLaunchOutcome(
          disposition: CodexManagedLaunchDisposition.blocked,
          route: preparation.route,
          preparation: preparation,
        );
      }

      final verifiedRoute = await _repository.getCodexLaunchRoute();
      if (!verifiedRoute.prepared ||
          verifiedRoute.revision != preparation.route.revision ||
          verifiedRoute.accountId != preparation.route.accountId) {
        throw StateError(
          'The prepared Codex account did not pass route read-back verification.',
        );
      }
      codexLaunchRoute = codexLaunchRoute.succeed(
        verifiedRoute,
        sourceSampleAt: verifiedRoute.sampledAt,
      );
      _notify();

      final managedBaseUrl = Uri.tryParse(integration.managedBaseUrl);
      if (managedBaseUrl == null) {
        throw StateError('The managed Codex loopback URL is invalid.');
      }
      Uri? appServerWebSocketUrl;
      if (_managedAppServerEnabled) {
        final prerequisites = await _codexProfilePrerequisites();
        final activeProfile = prerequisites.registry.activeProfile;
        final runtime = await _startCodexProfileRuntime(
          activeProfile,
          prerequisites.installation,
          prerequisites.integration,
        );
        appServerWebSocketUrl = runtime.endpoint;
      }
      final launch = await _codexDesktopLauncher.launch(
        managedBaseUrl: managedBaseUrl,
        appServerWebSocketUrl: appServerWebSocketUrl,
      );
      if (launch.alreadyRunning) {
        return CodexManagedLaunchOutcome(
          disposition: CodexManagedLaunchDisposition.alreadyRunning,
          route: verifiedRoute,
          preparation: preparation,
        );
      }
      if (!launch.launched || !launch.managed) {
        throw StateError('Windows did not confirm the Codex launch.');
      }
      codexModeChangeAffectsNextLaunch = false;
      return CodexManagedLaunchOutcome(
        disposition: CodexManagedLaunchDisposition.launchedManaged,
        route: verifiedRoute,
        preparation: preparation,
      );
    } on Object catch (error) {
      codexLaunchActionError = error;
      if (error is ApiException && error.statusCode == 409) {
        await _reloadCodexLaunchRouteAfterConflict();
      }
      return null;
    } finally {
      codexLaunchActionBusy = false;
      _notify();
    }
  }

  Future<void> _reloadCodexLaunchRouteAfterConflict() async {
    if (_codexLaunchRouteRefresh != null) {
      await _codexLaunchRouteRefresh;
    }
    _codexLaunchRouteRefresh = null;
    await refreshCodexLaunchRoute();
  }

  Future<bool> createAutomation(Map<String, Object?> payload) async {
    if (!canWrite || automationActionBusy) {
      return false;
    }
    automationActionBusy = true;
    automationActionError = null;
    _notify();
    try {
      await _repository.createAutomation(payload);
      await _reloadAutomationsAfterMutation();
      return true;
    } on Object catch (error) {
      automationActionError = error;
      return false;
    } finally {
      automationActionBusy = false;
      _notify();
    }
  }

  Future<bool> updateAutomation(
    String automationId,
    Map<String, Object?> payload,
  ) async {
    if (!canWrite || mutatingAutomationIds.contains(automationId)) {
      return false;
    }
    mutatingAutomationIds.add(automationId);
    automationActionError = null;
    _notify();
    try {
      await _repository.updateAutomation(automationId, payload);
      await _reloadAutomationsAfterMutation();
      return true;
    } on Object catch (error) {
      automationActionError = error;
      return false;
    } finally {
      mutatingAutomationIds.remove(automationId);
      _notify();
    }
  }

  Future<bool> deleteAutomation(String automationId) async {
    if (!canWrite || mutatingAutomationIds.contains(automationId)) {
      return false;
    }
    mutatingAutomationIds.add(automationId);
    automationActionError = null;
    _notify();
    try {
      await _repository.deleteAutomation(automationId);
      await _reloadAutomationsAfterMutation(includeRuns: true);
      return true;
    } on Object catch (error) {
      automationActionError = error;
      return false;
    } finally {
      mutatingAutomationIds.remove(automationId);
      _notify();
    }
  }

  Future<bool> runAutomationNow(String automationId) async {
    if (!canWrite || mutatingAutomationIds.contains(automationId)) {
      return false;
    }
    mutatingAutomationIds.add(automationId);
    automationActionError = null;
    _notify();
    try {
      await _repository.runAutomationNow(automationId);
      await _reloadAutomationsAfterMutation(includeRuns: true);
      return true;
    } on Object catch (error) {
      automationActionError = error;
      return false;
    } finally {
      mutatingAutomationIds.remove(automationId);
      _notify();
    }
  }

  Future<AutomationRunDetails?> getAutomationRunDetails(String runId) async {
    try {
      return await _repository.getAutomationRunDetails(runId);
    } on Object catch (error) {
      automationActionError = error;
      _notify();
      return null;
    }
  }

  Future<bool> createUpstreamProxyEndpoint(Map<String, Object?> payload) async {
    if (!canWrite || proxyActionBusy) {
      return false;
    }
    proxyActionBusy = true;
    proxyActionError = null;
    _notify();
    try {
      await _repository.createUpstreamProxyEndpoint(payload);
      await _reloadProxyAfterMutation();
      return true;
    } on Object catch (error) {
      proxyActionError = error;
      return false;
    } finally {
      proxyActionBusy = false;
      _notify();
    }
  }

  Future<UpstreamProxyTestResult?> testUpstreamProxyEndpoint(
    String endpointId,
  ) async {
    if (!canWrite || proxyActionBusy) {
      return null;
    }
    proxyActionBusy = true;
    proxyActionError = null;
    _notify();
    try {
      return await _repository.testUpstreamProxyEndpoint(endpointId);
    } on Object catch (error) {
      proxyActionError = error;
      return null;
    } finally {
      proxyActionBusy = false;
      _notify();
    }
  }

  Future<bool> createUpstreamProxyPool(Map<String, Object?> payload) async {
    if (!canWrite || proxyActionBusy) {
      return false;
    }
    proxyActionBusy = true;
    proxyActionError = null;
    _notify();
    try {
      await _repository.createUpstreamProxyPool(payload);
      await _reloadProxyAfterMutation();
      return true;
    } on Object catch (error) {
      proxyActionError = error;
      return false;
    } finally {
      proxyActionBusy = false;
      _notify();
    }
  }

  Future<bool> putAccountProxyBinding(String accountId, String poolId) async {
    if (!canWrite || proxyActionBusy) {
      return false;
    }
    proxyActionBusy = true;
    proxyActionError = null;
    _notify();
    try {
      await _repository.putAccountProxyBinding(accountId, poolId);
      await _reloadProxyAfterMutation(includeAccounts: true);
      return true;
    } on Object catch (error) {
      proxyActionError = error;
      return false;
    } finally {
      proxyActionBusy = false;
      _notify();
    }
  }

  Future<bool> createModelSource(Map<String, Object?> payload) {
    return _runAdvancedSettingsMutation(() async {
      await _repository.createModelSource(payload);
      await _reloadModelSourcesAfterMutation();
    });
  }

  Future<bool> updateModelSource(
    String sourceId,
    Map<String, Object?> payload,
  ) {
    return _runAdvancedSettingsMutation(() async {
      await _repository.updateModelSource(sourceId, payload);
      await _reloadModelSourcesAfterMutation();
    });
  }

  Future<bool> deleteModelSource(String sourceId) {
    return _runAdvancedSettingsMutation(() async {
      await _repository.deleteModelSource(sourceId);
      await _reloadModelSourcesAfterMutation();
    });
  }

  Future<bool> addFirewallIp(String ipAddress) {
    return _runAdvancedSettingsMutation(() async {
      await _repository.addFirewallIp(ipAddress);
      await _reloadFirewallAfterMutation();
    });
  }

  Future<bool> deleteFirewallIp(String ipAddress) {
    return _runAdvancedSettingsMutation(() async {
      await _repository.deleteFirewallIp(ipAddress);
      await _reloadFirewallAfterMutation();
    });
  }

  Future<bool> updateQuotaPlannerSettings(Map<String, Object?> payload) {
    return _runAdvancedSettingsMutation(() async {
      await _repository.updateQuotaPlannerSettings(payload);
      await _reloadQuotaPlannerAfterMutation();
    });
  }

  Future<QuotaPlannerActionResult?> warmQuotaPlannerAccount(
    String accountId, {
    String? model,
    bool forceProbe = false,
  }) {
    return _runAdvancedSettingsResult(() async {
      final result = await _repository.warmQuotaPlannerAccount(
        accountId,
        model: model,
        forceProbe: forceProbe,
      );
      await _reloadQuotaPlannerAfterMutation();
      return result;
    });
  }

  Future<bool> cancelQuotaPlannerDecision(String decisionId) {
    return _runAdvancedSettingsMutation(() async {
      await _repository.cancelQuotaPlannerDecision(decisionId);
      await _reloadQuotaPlannerAfterMutation();
    });
  }

  Future<bool> deleteStickySession(StickySessionEntry entry) {
    return _runAdvancedSettingsMutation(() async {
      await _repository.deleteStickySession(entry);
      await _reloadStickySessionsAfterMutation();
    });
  }

  Future<int?> purgeStaleStickySessions() {
    return _runAdvancedSettingsResult(() async {
      final count = await _repository.purgeStaleStickySessions();
      await _reloadStickySessionsAfterMutation();
      return count;
    });
  }

  Future<bool> _runAdvancedSettingsMutation(
    Future<void> Function() mutation,
  ) async {
    final result = await _runAdvancedSettingsResult<bool>(() async {
      await mutation();
      return true;
    });
    return result ?? false;
  }

  Future<T?> _runAdvancedSettingsResult<T>(Future<T> Function() action) async {
    if (!canWrite || advancedSettingsActionBusy) {
      return null;
    }
    advancedSettingsActionBusy = true;
    advancedSettingsActionError = null;
    _notify();
    try {
      return await action();
    } on Object catch (error) {
      advancedSettingsActionError = error;
      return null;
    } finally {
      advancedSettingsActionBusy = false;
      _notify();
    }
  }

  Future<void> _reloadModelSourcesAfterMutation() async {
    if (_modelSourcesRefresh != null) {
      await _modelSourcesRefresh;
    }
    _modelSourcesRefresh = null;
    await refreshModelSources();
  }

  Future<void> _reloadFirewallAfterMutation() async {
    if (_firewallRefresh != null) {
      await _firewallRefresh;
    }
    _firewallRefresh = null;
    await refreshFirewall();
  }

  Future<void> _reloadQuotaPlannerAfterMutation() async {
    if (_quotaPlannerRefresh != null) {
      await _quotaPlannerRefresh;
    }
    _quotaPlannerRefresh = null;
    await refreshQuotaPlanner();
  }

  Future<void> _reloadStickySessionsAfterMutation() async {
    if (_stickySessionsRefresh != null) {
      await _stickySessionsRefresh;
    }
    _stickySessionsRefresh = null;
    await refreshStickySessions();
  }

  Future<void> shutdown() async {
    if (_disposed) {
      return;
    }
    runtime = RuntimeViewState(
      phase: RuntimePhase.stopping,
      connection: runtime.connection,
    );
    _notify();
    await _codexAppServerSupervisor.stop();
    await _oxBridgeSupervisor.stop();
    await _supervisor.stopOwned();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_codexAppServerSupervisor.stop());
    unawaited(_oxBridgeSupervisor.stop());
    unawaited(_supervisor.stopOwned());
    _client.close();
    super.dispose();
  }
}
