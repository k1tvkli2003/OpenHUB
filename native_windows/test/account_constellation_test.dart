import 'dart:async';
import 'dart:io';

import 'package:openhub_windows/src/core/api/local_api_client.dart';
import 'package:openhub_windows/src/core/runtime/runtime_config.dart';
import 'package:openhub_windows/src/data/openhub_repository.dart';
import 'package:openhub_windows/src/models/account_operations.dart';
import 'package:openhub_windows/src/models/account_summary.dart';
import 'package:openhub_windows/src/models/auth_session.dart';
import 'package:openhub_windows/src/state/app_controller.dart';
import 'package:openhub_windows/src/state/async_section.dart';
import 'package:openhub_windows/src/ui/app_theme.dart';
import 'package:openhub_windows/src/ui/features/accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const goldenKey = ValueKey<String>('account-constellation-golden');
  test(
    'Accounts navigation requests live usage and joins one refresh',
    () async {
      final now = DateTime.now().toUtc();
      final refreshGate = Completer<void>();
      final harness = _Harness(
        <AccountSummary>[
          _account(id: 'live', name: 'Live row', remaining: 80, sampleAt: now),
        ],
        sessionStartedAt: now.subtract(const Duration(minutes: 1)),
        refreshGate: refreshGate,
      );
      addTearDown(harness.close);
      harness.controller.auth = const AsyncSection<AuthSession>(
        phase: SectionPhase.ready,
        value: AuthSession(
          authenticated: true,
          passwordRequired: false,
          totpRequiredOnLogin: false,
          totpConfigured: false,
          bootstrapRequired: false,
          bootstrapTokenConfigured: false,
          authMode: 'loopback',
          passwordManagementEnabled: true,
          passwordSessionActive: true,
          role: 'admin',
          permissions: <String>{'read', 'write'},
          guestAccessEnabled: false,
          guestPasswordRequired: false,
        ),
      );

      harness.controller.selectDestination(
        AppDestination.pulse,
        refresh: false,
      );
      harness.controller.selectDestination(AppDestination.accounts);
      await Future<void>.delayed(Duration.zero);
      final joinedRefresh = harness.controller.refreshAccountUsage();

      expect(harness.repository.listAccountsCalls, 1);
      expect(harness.repository.refreshAccountsCalls, 1);
      refreshGate.complete();
      await joinedRefresh;
      expect(harness.repository.refreshAccountsCalls, 1);
    },
  );

  testWidgets(
    'account constellation groups session freshness and preserves management actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now().toUtc();
      final sessionStartedAt = now.subtract(const Duration(minutes: 1));
      final accounts = <AccountSummary>[
        _account(
          id: 'free',
          name: 'Free archive',
          remaining: 99,
          sampleAt: now,
          planType: 'free',
        ),
        _account(
          id: 'fresh',
          name: 'Fresh leader',
          remaining: 92,
          sampleAt: now,
          resetAtPrimary: now.add(
            const Duration(hours: 2, minutes: 15, seconds: 30),
          ),
          resetAtSecondary: now.add(
            const Duration(days: 3, hours: 8, minutes: 30),
          ),
        ),
        _account(
          id: 'fresh-alt',
          name: 'Fresh runner',
          remaining: 82,
          sampleAt: now,
        ),
        _account(
          id: 'cached',
          name: 'Cached runner',
          remaining: 71,
          sampleAt: sessionStartedAt.subtract(const Duration(seconds: 1)),
        ),
        _account(
          id: 'reauth',
          name: 'Needs login',
          remaining: 45,
          sampleAt: now,
          status: 'reauth_required',
        ),
        _account(id: 'empty', name: 'No quota', remaining: 0, sampleAt: now),
      ];
      final harness = _Harness(accounts, sessionStartedAt: sessionStartedAt);
      addTearDown(harness.close);
      harness.controller.accounts = AsyncSection<List<AccountSummary>>(
        phase: SectionPhase.ready,
        value: accounts,
        lastSuccessfulFetch: now,
        sourceSampleAt: now,
      );
      await harness.controller.refreshAccountUsage();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: goldenKey,
              child: AccountsPage(controller: harness.controller),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('goldens/account_constellation_readable.png'),
      );

      expect(find.text('READY NOW'), findsOneWidget);
      expect(find.text('NEEDS ATTENTION'), findsOneWidget);
      expect(find.text('Refresh failed'), findsWidgets);
      expect(find.text('Reauth required'), findsWidgets);
      expect(find.text('NEXT ROUTE'), findsOneWidget);
      expect(find.text('BEST NOW'), findsOneWidget);
      expect(find.text('RUNNER-UP'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('next-route-fresh')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('next-route-fresh-alt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('next-route-cached')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('next-route-free')),
        findsNothing,
      );
      expect(find.textContaining('ChatGPT Plus · cached'), findsWidgets);
      expect(find.text('02h 15m'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('quota-reset-fresh')),
        findsOneWidget,
      );
      expect(
        harness.controller.accountUsageRefreshFailedIds,
        contains('cached'),
      );
      expect(
        harness.controller.accountUsageRefreshFailedIds,
        isNot(contains('reauth')),
      );
      expect(
        find.byTooltip('Open Codex with Fresh leader for one new process'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Inspect and manage account').first);
      await tester.pumpAndSettle();
      expect(find.text('Routing policy'), findsOneWidget);
      expect(find.text('Limit warmup'), findsOneWidget);
      expect(find.text('Security work authorized'), findsOneWidget);
      expect(find.text('Probe'), findsOneWidget);
      expect(find.textContaining('Reset credit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.byTooltip('Close account details'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const PageStorageKey<String>('native-account-list')),
        const Offset(0, -520),
      );
      await tester.pump();
      expect(find.text('OFFLINE / EXHAUSTED'), findsOneWidget);
      expect(find.text('Quota exhausted'), findsWidgets);
      expect(find.text('Free plan · not routable'), findsWidgets);
      expect(
        find.byTooltip(
          'Free subscriptions are excluded from manual Codex launch and every routing mode.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets('expanded rows show every reported quota reset window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now().toUtc();
    final account = _account(
      id: 'all-reset-windows',
      name: 'Reset windows',
      remaining: 76,
      sampleAt: now,
      resetAtPrimary: now.add(
        const Duration(hours: 2, minutes: 15, seconds: 30),
      ),
      resetAtSecondary: now.add(const Duration(days: 3, hours: 8, minutes: 30)),
    );
    final harness = _Harness(<AccountSummary>[
      account,
    ], sessionStartedAt: now.subtract(const Duration(minutes: 1)));
    addTearDown(harness.close);
    harness.controller.accounts = AsyncSection<List<AccountSummary>>(
      phase: SectionPhase.ready,
      value: <AccountSummary>[account],
      lastSuccessfulFetch: now,
      sourceSampleAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: AccountsPage(controller: harness.controller)),
      ),
    );
    await tester.pump();

    expect(find.text('5H'), findsOneWidget);
    expect(find.text('02h 15m'), findsOneWidget);
    expect(find.text('7D'), findsOneWidget);
    expect(find.text('3d 08h'), findsOneWidget);
  });

  testWidgets('subscription filter isolates paid and free accounts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now().toUtc();
    final accounts = <AccountSummary>[
      _account(
        id: 'paid-filter-row',
        name: 'Paid filter row',
        remaining: 80,
        sampleAt: now,
        planType: 'plus',
      ),
      _account(
        id: 'free-filter-row',
        name: 'Free filter row',
        remaining: 70,
        sampleAt: now,
        planType: 'free',
      ),
      _account(
        id: 'unknown-filter-row',
        name: 'Unknown filter row',
        remaining: 60,
        sampleAt: now,
        planType: 'unknown',
      ),
    ];
    final harness = _Harness(
      accounts,
      sessionStartedAt: now.subtract(const Duration(minutes: 1)),
    );
    addTearDown(harness.close);
    harness.controller.accounts = AsyncSection<List<AccountSummary>>(
      phase: SectionPhase.ready,
      value: accounts,
      lastSuccessfulFetch: now,
      sourceSampleAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: AccountsPage(controller: harness.controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('account-row-paid-filter-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('account-row-free-filter-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('account-row-unknown-filter-row')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('account-subscription-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paid only').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('account-row-paid-filter-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('account-row-free-filter-row')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('account-row-unknown-filter-row')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('account-subscription-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free only').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('account-row-paid-filter-row')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('account-row-free-filter-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('account-row-unknown-filter-row')),
      findsNothing,
    );
  });
}

AccountSummary _account({
  required String id,
  required String name,
  required double remaining,
  required DateTime sampleAt,
  String status = 'active',
  String? planType,
  DateTime? resetAtPrimary,
  DateTime? resetAtSecondary,
}) {
  return AccountSummary(
    accountId: id,
    email: '$id@example.invalid',
    displayName: name,
    planType: planType ?? (id == 'fresh' ? 'pro' : 'plus'),
    routingPolicy: 'normal',
    status: status,
    securityWorkAuthorized: false,
    usage: AccountUsage(primaryRemainingPercent: remaining),
    lastRefreshAt: sampleAt.subtract(const Duration(minutes: 8)),
    usageSampleAt: sampleAt,
    requestUsage: null,
    isEmailDuplicate: false,
    availableResetCredits: 0,
    resetAtPrimary: resetAtPrimary,
    resetAtSecondary: resetAtSecondary,
    windowMinutesPrimary: 300,
    windowMinutesSecondary: 10080,
  );
}

class _Harness {
  _Harness(
    List<AccountSummary> accounts, {
    required DateTime sessionStartedAt,
    Completer<void>? refreshGate,
  }) : root = Directory.systemTemp.createTempSync(
         'openhub-account-constellation-',
       ),
       repository = _Repository(accounts, refreshGate: refreshGate) {
    controller = AppController(
      config: RuntimeConfig(
        endpoint: Uri.parse('http://127.0.0.1:1'),
        dataDirectory: Directory('${root.path}\\data'),
        backupDirectory: Directory('${root.path}\\backup'),
        backendExecutable: null,
        attachOnly: true,
      ),
      sessionStartedAt: sessionStartedAt,
      repository: repository,
    );
  }

  final Directory root;
  final _Repository repository;
  late final AppController controller;

  void close() {
    controller.dispose();
    repository.close();
    if (root.existsSync() &&
        root.path.contains('openhub-account-constellation-')) {
      root.deleteSync(recursive: true);
    }
  }
}

class _Repository extends OpenHubRepository {
  _Repository._(this.accounts, this._client, this.refreshGate) : super(_client);

  factory _Repository(
    List<AccountSummary> accounts, {
    Completer<void>? refreshGate,
  }) {
    final client = LocalApiClient(endpoint: Uri.parse('http://127.0.0.1:1'));
    return _Repository._(accounts, client, refreshGate);
  }

  final List<AccountSummary> accounts;
  final LocalApiClient _client;
  final Completer<void>? refreshGate;
  int listAccountsCalls = 0;
  int refreshAccountsCalls = 0;

  @override
  Future<List<AccountSummary>> listAccounts() async {
    listAccountsCalls += 1;
    return accounts;
  }

  @override
  Future<List<AccountSummary>> refreshAccounts() async {
    refreshAccountsCalls += 1;
    await refreshGate?.future;
    return accounts;
  }

  @override
  Future<AccountTrends> getAccountTrends(String accountId) async {
    return AccountTrends(
      accountId: accountId,
      primary: const <UsageTrendPoint>[],
      secondary: const <UsageTrendPoint>[],
      secondaryScheduled: const <UsageTrendPoint>[],
    );
  }

  @override
  Future<AccountUsageResetCredits> getAccountUsageResetCredits(
    String accountId,
  ) async {
    return AccountUsageResetCredits(accountId: accountId, availableCount: 0);
  }

  void close() => _client.close();
}
