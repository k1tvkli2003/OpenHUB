import 'package:openhub_windows/src/models/account_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remaining usage orders known accounts in both directions', () {
    final accounts = <AccountSummary>[
      _account('unknown', 'Unknown', null),
      _account('low', 'Low', 12),
      _account('high', 'High', 91),
      _account('middle', 'Middle', 54),
    ];

    expect(
      orderAccountsByRemainingUsage(accounts).map((item) => item.accountId),
      <String>['high', 'middle', 'low', 'unknown'],
    );
    expect(
      orderAccountsByRemainingUsage(
        accounts,
        order: AccountRemainingUsageOrder.lowestFirst,
      ).map((item) => item.accountId),
      <String>['low', 'middle', 'high', 'unknown'],
    );
  });

  test('unknown usage stays last and equal usage has a stable name order', () {
    final accounts = <AccountSummary>[
      _account('zulu', 'Zulu', 50),
      _account('unknown-b', 'Unknown B', null),
      _account('alpha', 'Alpha', 50),
      _account('unknown-a', 'Unknown A', null),
    ];

    expect(
      orderAccountsByRemainingUsage(accounts).map((item) => item.accountId),
      <String>['alpha', 'zulu', 'unknown-a', 'unknown-b'],
    );
  });
}

AccountSummary _account(String id, String name, double? remaining) {
  return AccountSummary(
    accountId: id,
    email: '$id@example.invalid',
    displayName: name,
    planType: 'plus',
    routingPolicy: 'normal',
    status: 'active',
    securityWorkAuthorized: false,
    usage: remaining == null
        ? null
        : AccountUsage(primaryRemainingPercent: remaining),
    lastRefreshAt: null,
    requestUsage: null,
    isEmailDuplicate: false,
    availableResetCredits: 0,
  );
}
