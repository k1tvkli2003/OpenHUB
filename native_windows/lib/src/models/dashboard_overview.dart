import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';
import 'account_summary.dart';

class QuotaWindow {
  const QuotaWindow({
    required this.remainingPercent,
    required this.capacityCredits,
    required this.remainingCredits,
    required this.resetAt,
    required this.windowMinutes,
  });

  final double remainingPercent;
  final double capacityCredits;
  final double remainingCredits;
  final DateTime? resetAt;
  final int? windowMinutes;

  factory QuotaWindow.fromJson(Map<String, Object?> json, String context) {
    return QuotaWindow(
      remainingPercent: readNumber(
        json,
        'remainingPercent',
        context,
      ).toDouble(),
      capacityCredits: readNumber(json, 'capacityCredits', context).toDouble(),
      remainingCredits: readNumber(
        json,
        'remainingCredits',
        context,
      ).toDouble(),
      resetAt: readNullableDateTime(json, 'resetAt', context),
      windowMinutes: readNullableNumber(
        json,
        'windowMinutes',
        context,
      )?.toInt(),
    );
  }
}

class DashboardMetrics {
  const DashboardMetrics({
    required this.requests,
    required this.tokens,
    required this.conversations,
    required this.errorRate,
    required this.errorCount,
    required this.topError,
  });

  final int? requests;
  final int? tokens;
  final int conversations;
  final double? errorRate;
  final int? errorCount;
  final String? topError;

  factory DashboardMetrics.fromJson(Map<String, Object?> json) {
    return DashboardMetrics(
      requests: readNullableNumber(
        json,
        'requests',
        'overview.summary.metrics',
      )?.toInt(),
      tokens: readNullableNumber(
        json,
        'tokens',
        'overview.summary.metrics',
      )?.toInt(),
      conversations:
          readNullableNumber(
            json,
            'conversations',
            'overview.summary.metrics',
          )?.toInt() ??
          0,
      errorRate: readNullableNumber(
        json,
        'errorRate',
        'overview.summary.metrics',
      )?.toDouble(),
      errorCount: readNullableNumber(
        json,
        'errorCount',
        'overview.summary.metrics',
      )?.toInt(),
      topError: readNullableString(
        json,
        'topError',
        'overview.summary.metrics',
      ),
    );
  }
}

class DashboardOverview {
  const DashboardOverview({
    required this.lastSyncAt,
    required this.timeframe,
    required this.accounts,
    required this.primaryWindow,
    required this.secondaryWindow,
    required this.currency,
    required this.totalUsd,
    required this.metrics,
  });

  final DateTime? lastSyncAt;
  final String timeframe;
  final List<AccountSummary> accounts;
  final QuotaWindow primaryWindow;
  final QuotaWindow? secondaryWindow;
  final String currency;
  final double totalUsd;
  final DashboardMetrics? metrics;

  int get activeAccounts =>
      accounts.where((account) => account.isActive).length;
  int get attentionAccounts =>
      accounts.where((account) => account.requiresAttention).length;

  factory DashboardOverview.fromJson(Map<String, Object?> json) {
    final timeframeJson = readObject(json['timeframe'], 'overview.timeframe');
    final accountsJson = readList(json['accounts'], 'overview.accounts');
    final summary = readObject(json['summary'], 'overview.summary');
    final primary = readObject(
      summary['primaryWindow'],
      'overview.summary.primaryWindow',
    );
    final secondary = summary['secondaryWindow'];
    final cost = readObject(summary['cost'], 'overview.summary.cost');
    final metricsJson = summary['metrics'];

    final accounts = accountsJson
        .map(
          (item) =>
              AccountSummary.fromJson(readObject(item, 'overview.accounts[]')),
        )
        .toList(growable: false);
    if (accounts.length > 10000) {
      throw const ApiSchemaException(
        'Overview account count exceeds the native safety limit.',
      );
    }

    return DashboardOverview(
      lastSyncAt: readNullableDateTime(json, 'lastSyncAt', 'overview'),
      timeframe: readString(timeframeJson, 'key', 'overview.timeframe'),
      accounts: accounts,
      primaryWindow: QuotaWindow.fromJson(
        primary,
        'overview.summary.primaryWindow',
      ),
      secondaryWindow: secondary == null
          ? null
          : QuotaWindow.fromJson(
              readObject(secondary, 'overview.summary.secondaryWindow'),
              'overview.summary.secondaryWindow',
            ),
      currency: readString(cost, 'currency', 'overview.summary.cost'),
      totalUsd: readNumber(
        cost,
        'totalUsd',
        'overview.summary.cost',
      ).toDouble(),
      metrics: metricsJson == null
          ? null
          : DashboardMetrics.fromJson(
              readObject(metricsJson, 'overview.summary.metrics'),
            ),
    );
  }
}
