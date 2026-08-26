import 'dart:io';

import 'package:openhub_windows/src/core/api/local_api_client.dart';
import 'package:openhub_windows/src/core/runtime/runtime_config.dart';
import 'package:openhub_windows/src/data/openhub_repository.dart';
import 'package:openhub_windows/src/models/account_operations.dart';
import 'package:openhub_windows/src/models/account_summary.dart';
import 'package:openhub_windows/src/state/app_controller.dart';
import 'package:openhub_windows/src/state/async_section.dart';
import 'package:openhub_windows/src/ui/app_theme.dart';
import 'package:openhub_windows/src/ui/features/accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cached destination selection completes inside one 60 Hz frame', (
    tester,
  ) async {
    final harness = _ControllerHarness(<AccountSummary>[_account(0)]);
    addTearDown(harness.close);
    harness.controller.accounts = AsyncSection<List<AccountSummary>>(
      phase: SectionPhase.ready,
      value: harness.repository.accounts,
    );
    harness.controller.destination = AppDestination.reports;

    final clock = Stopwatch()..start();
    harness.controller.selectDestination(AppDestination.accounts);
    clock.stop();
    final elapsedMs = clock.elapsedMicroseconds / 1000;
    await tester.pump();

    debugPrint('PERF cachedNavigationWorstMs=${elapsedMs.toStringAsFixed(3)}');
    expect(elapsedMs, lessThan(16.67));
    expect(harness.repository.accountListCalls, 1);
  });

  testWidgets(
    '250-row account list stays virtualized under the debug regression guard',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final rows = List<AccountSummary>.generate(250, _account);
      final harness = _ControllerHarness(rows);
      addTearDown(harness.close);
      harness.controller.accounts = AsyncSection<List<AccountSummary>>(
        phase: SectionPhase.ready,
        value: rows,
        lastSuccessfulFetch: DateTime.now().toUtc(),
        sourceSampleAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: AccountsPage(controller: harness.controller)),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.textContaining('250 TOTAL'), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey<String>('native-account-list')),
        findsOneWidget,
      );
      expect(find.text('Account 000'), findsAtLeastNWidgets(1));
      expect(find.text('Account 249'), findsNothing);
      expect(find.textContaining('Quota checked'), findsWidgets);
      expect(find.textContaining('Sign-in refreshed'), findsWidgets);
      expect(
        find.byTooltip('Open Codex with Account 000 for one new process'),
        findsOneWidget,
      );

      final list = find.byKey(
        const PageStorageKey<String>('native-account-list'),
      );
      // Warm the debug JIT and lazy row builders before collecting wall-clock
      // samples. The release probe below remains the real 16.67 ms gate; this
      // guard should detect layout regressions, not one-time compilation work.
      for (var index = 0; index < 4; index += 1) {
        await tester.drag(list, const Offset(0, -360));
        await tester.pump();
      }
      final frameSamples = <double>[];
      for (var index = 0; index < 24; index += 1) {
        await tester.drag(list, const Offset(0, -360));
        final clock = Stopwatch()..start();
        // Measure build/layout work only. Supplying a duration here advances the
        // fake frame clock and incorrectly adds that simulated interval to the
        // wall-clock sample.
        await tester.pump();
        clock.stop();
        frameSamples.add(clock.elapsedMicroseconds / 1000);
      }
      frameSamples.sort();
      final medianMs =
          (frameSamples[(frameSamples.length ~/ 2) - 1] +
              frameSamples[frameSamples.length ~/ 2]) /
          2;
      final p95Index = ((frameSamples.length - 1) * 0.95).round();
      final p95Ms = frameSamples[p95Index];
      final worstMs = frameSamples.last;
      debugPrint(
        'PERF_DEBUG accountRows=250 scrollMedianMs=${medianMs.toStringAsFixed(3)} '
        'scrollP95Ms=${p95Ms.toStringAsFixed(3)} '
        'scrollWorstMs=${worstMs.toStringAsFixed(3)}',
      );
      expect(
        medianMs,
        lessThan(35),
        reason:
            'This JIT-warmed debug guard catches sustained regressions; the '
            '16.67 ms frame budget is enforced by the opt-in Windows release '
            'probe.',
      );
      expect(
        p95Ms,
        lessThan(75),
        reason:
            'The shared CI runner may have isolated scheduling spikes, but its '
            'JIT-warmed p95 must still reject a broad layout regression.',
      );

      final detailCallsAfterInitialBuild = harness.repository.detailCalls;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: AccountsPage(controller: harness.controller)),
        ),
      );
      await tester.pump();
      expect(
        harness.repository.detailCalls,
        detailCallsAfterInitialBuild,
        reason: 'A widget rebuild must not duplicate account-detail fetches.',
      );
    },
  );
}

AccountSummary _account(int index) {
  final suffix = index.toString().padLeft(3, '0');
  return AccountSummary(
    accountId: 'fixture-account-$suffix',
    email: 'fixture-$suffix@example.invalid',
    displayName: 'Account $suffix',
    planType: 'plus',
    routingPolicy: 'normal',
    status: 'active',
    securityWorkAuthorized: false,
    usage: AccountUsage(primaryRemainingPercent: 100 - (index % 100)),
    lastRefreshAt: DateTime.utc(2026, 8, 9, 12),
    usageSampleAt: DateTime.utc(2026, 8, 9, 12, 1),
    requestUsage: null,
    isEmailDuplicate: false,
    availableResetCredits: 0,
  );
}

class _ControllerHarness {
  _ControllerHarness(List<AccountSummary> accounts)
    : root = Directory.systemTemp.createTempSync('openhub-native-performance-'),
      repository = _CountingRepository(accounts) {
    controller = AppController(
      config: RuntimeConfig(
        endpoint: Uri.parse('http://127.0.0.1:1'),
        dataDirectory: Directory('${root.path}\\data'),
        backupDirectory: Directory('${root.path}\\backup'),
        backendExecutable: null,
        attachOnly: true,
      ),
      repository: repository,
    );
  }

  final Directory root;
  final _CountingRepository repository;
  late final AppController controller;

  void close() {
    controller.dispose();
    repository.close();
    if (root.existsSync() &&
        root.path.contains('openhub-native-performance-')) {
      root.deleteSync(recursive: true);
    }
  }
}

class _CountingRepository extends OpenHubRepository {
  _CountingRepository._(this.accounts, this._client) : super(_client);

  factory _CountingRepository(List<AccountSummary> accounts) {
    final client = LocalApiClient(endpoint: Uri.parse('http://127.0.0.1:1'));
    return _CountingRepository._(accounts, client);
  }

  final List<AccountSummary> accounts;
  final LocalApiClient _client;
  int accountListCalls = 0;
  int detailCalls = 0;

  @override
  Future<List<AccountSummary>> listAccounts() async {
    accountListCalls += 1;
    return accounts;
  }

  @override
  Future<AccountTrends> getAccountTrends(String accountId) async {
    detailCalls += 1;
    throw StateError('Synthetic performance fixture has no trends.');
  }

  @override
  Future<AccountUsageResetCredits> getAccountUsageResetCredits(
    String accountId,
  ) async {
    detailCalls += 1;
    throw StateError('Synthetic performance fixture has no reset credits.');
  }

  void close() => _client.close();
}
