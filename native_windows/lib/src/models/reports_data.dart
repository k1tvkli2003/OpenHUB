import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

class DailyReportRow {
  const DailyReportRow({
    required this.date,
    required this.requests,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedInputTokens,
    required this.costUsd,
    required this.activeAccounts,
    required this.conversations,
    required this.errorCount,
    required this.medianTtftMs,
    required this.medianTps,
    required this.medianQueueMs,
  });

  final String date;
  final int requests;
  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;
  final double costUsd;
  final int activeAccounts;
  final int conversations;
  final int errorCount;
  final double medianTtftMs;
  final double medianTps;
  final double medianQueueMs;

  int get totalTokens => inputTokens + outputTokens;

  factory DailyReportRow.fromJson(Map<String, Object?> json) {
    return DailyReportRow(
      date: readString(json, 'date', 'reports.daily[]'),
      requests: readInt(json, 'requests', 'reports.daily[]'),
      inputTokens: readInt(json, 'inputTokens', 'reports.daily[]'),
      outputTokens: readInt(json, 'outputTokens', 'reports.daily[]'),
      cachedInputTokens: readInt(json, 'cachedInputTokens', 'reports.daily[]'),
      costUsd: readNumber(json, 'costUsd', 'reports.daily[]').toDouble(),
      activeAccounts: readInt(json, 'activeAccounts', 'reports.daily[]'),
      conversations:
          readNullableNumber(
            json,
            'conversations',
            'reports.daily[]',
          )?.toInt() ??
          0,
      errorCount:
          readNullableNumber(json, 'errorCount', 'reports.daily[]')?.toInt() ??
          0,
      medianTtftMs:
          readNullableNumber(
            json,
            'medianTtftMs',
            'reports.daily[]',
          )?.toDouble() ??
          0,
      medianTps:
          readNullableNumber(
            json,
            'medianTps',
            'reports.daily[]',
          )?.toDouble() ??
          0,
      medianQueueMs:
          readNullableNumber(
            json,
            'medianQueueMs',
            'reports.daily[]',
          )?.toDouble() ??
          0,
    );
  }
}

class ReportSummary {
  const ReportSummary({
    required this.totalCostUsd,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalCachedTokens,
    required this.totalRequests,
    required this.totalErrors,
    required this.activeAccounts,
    required this.totalConversations,
    required this.avgCostPerDay,
    required this.avgRequestsPerDay,
  });

  final double totalCostUsd;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCachedTokens;
  final int totalRequests;
  final int totalErrors;
  final int activeAccounts;
  final int totalConversations;
  final double avgCostPerDay;
  final double avgRequestsPerDay;

  int get totalTokens => totalInputTokens + totalOutputTokens;

  factory ReportSummary.fromJson(Map<String, Object?> json) {
    const context = 'reports.summary';
    return ReportSummary(
      totalCostUsd: readNumber(json, 'totalCostUsd', context).toDouble(),
      totalInputTokens: readInt(json, 'totalInputTokens', context),
      totalOutputTokens: readInt(json, 'totalOutputTokens', context),
      totalCachedTokens: readInt(json, 'totalCachedTokens', context),
      totalRequests: readInt(json, 'totalRequests', context),
      totalErrors: readInt(json, 'totalErrors', context),
      activeAccounts: readInt(json, 'activeAccounts', context),
      totalConversations:
          readNullableNumber(json, 'totalConversations', context)?.toInt() ?? 0,
      avgCostPerDay:
          readNullableNumber(json, 'avgCostPerDay', context)?.toDouble() ?? 0,
      avgRequestsPerDay:
          readNullableNumber(json, 'avgRequestsPerDay', context)?.toDouble() ??
          0,
    );
  }
}

class ReportComparison {
  const ReportComparison({
    required this.canCompare,
    required this.previousCostUsd,
    required this.previousTokens,
    required this.previousRequests,
  });

  final bool canCompare;
  final double previousCostUsd;
  final int previousTokens;
  final int previousRequests;

  factory ReportComparison.fromJson(Map<String, Object?> json) {
    final previous = readObject(
      json['previous'],
      'reports.comparison.previous',
    );
    return ReportComparison(
      canCompare: readBool(json, 'canCompare', 'reports.comparison'),
      previousCostUsd: readNumber(
        previous,
        'totalCostUsd',
        'reports.comparison.previous',
      ).toDouble(),
      previousTokens: readInt(
        previous,
        'totalTokens',
        'reports.comparison.previous',
      ),
      previousRequests: readInt(
        previous,
        'totalRequests',
        'reports.comparison.previous',
      ),
    );
  }
}

class ModelCostEntry {
  const ModelCostEntry({
    required this.model,
    required this.costUsd,
    required this.requests,
    required this.percentage,
  });

  final String model;
  final double costUsd;
  final int requests;
  final double percentage;

  factory ModelCostEntry.fromJson(Map<String, Object?> json) {
    const context = 'reports.byModel[]';
    return ModelCostEntry(
      model: readString(json, 'model', context),
      costUsd: readNumber(json, 'costUsd', context).toDouble(),
      requests: readInt(json, 'requests', context),
      percentage: readNumber(json, 'percentage', context).toDouble(),
    );
  }
}

class AccountCostEntry {
  const AccountCostEntry({
    required this.accountId,
    required this.alias,
    required this.costUsd,
    required this.requests,
  });

  final String? accountId;
  final String? alias;
  final double costUsd;
  final int requests;

  factory AccountCostEntry.fromJson(Map<String, Object?> json) {
    const context = 'reports.byAccount[]';
    return AccountCostEntry(
      accountId: readNullableString(json, 'accountId', context),
      alias: readNullableString(json, 'alias', context),
      costUsd: readNumber(json, 'costUsd', context).toDouble(),
      requests: readInt(json, 'requests', context),
    );
  }
}

class UserAgentCostEntry {
  const UserAgentCostEntry({
    required this.userAgent,
    required this.costUsd,
    required this.requests,
    required this.percentage,
  });

  final String userAgent;
  final double costUsd;
  final int requests;
  final double percentage;

  factory UserAgentCostEntry.fromJson(Map<String, Object?> json) {
    const context = 'reports.byUseragent[]';
    return UserAgentCostEntry(
      userAgent: readString(json, 'useragent', context),
      costUsd: readNumber(json, 'costUsd', context).toDouble(),
      requests: readInt(json, 'requests', context),
      percentage: readNumber(json, 'percentage', context).toDouble(),
    );
  }
}

class ReportsData {
  const ReportsData({
    required this.summary,
    required this.comparison,
    required this.daily,
    required this.byModel,
    required this.byAccount,
    required this.byUserAgent,
  });

  final ReportSummary summary;
  final ReportComparison comparison;
  final List<DailyReportRow> daily;
  final List<ModelCostEntry> byModel;
  final List<AccountCostEntry> byAccount;
  final List<UserAgentCostEntry> byUserAgent;

  factory ReportsData.fromJson(Map<String, Object?> json) {
    final daily = readList(json['daily'], 'reports.daily')
        .map(
          (item) =>
              DailyReportRow.fromJson(readObject(item, 'reports.daily[]')),
        )
        .toList(growable: false);
    final byModel = readList(json['byModel'], 'reports.byModel')
        .map(
          (item) =>
              ModelCostEntry.fromJson(readObject(item, 'reports.byModel[]')),
        )
        .toList(growable: false);
    final byAccount = readList(json['byAccount'], 'reports.byAccount')
        .map(
          (item) => AccountCostEntry.fromJson(
            readObject(item, 'reports.byAccount[]'),
          ),
        )
        .toList(growable: false);
    final byUserAgent = readList(json['byUseragent'], 'reports.byUseragent')
        .map(
          (item) => UserAgentCostEntry.fromJson(
            readObject(item, 'reports.byUseragent[]'),
          ),
        )
        .toList(growable: false);
    if (daily.length > 3660 ||
        byModel.length > 10000 ||
        byAccount.length > 10000 ||
        byUserAgent.length > 10000) {
      throw const ApiSchemaException('Reports response exceeds native limits.');
    }
    return ReportsData(
      summary: ReportSummary.fromJson(
        readObject(json['summary'], 'reports.summary'),
      ),
      comparison: ReportComparison.fromJson(
        readObject(json['comparison'], 'reports.comparison'),
      ),
      daily: daily,
      byModel: byModel,
      byAccount: byAccount,
      byUserAgent: byUserAgent,
    );
  }
}

class ReportsQuery {
  const ReportsQuery({
    this.startDate,
    this.endDate,
    this.timezone,
    this.accountIds = const <String>[],
    this.model,
    this.userAgentGroup,
  });

  final String? startDate;
  final String? endDate;
  final String? timezone;
  final List<String> accountIds;
  final String? model;
  final String? userAgentGroup;

  Map<String, Object?> toQuery() => <String, Object?>{
    'start_date': startDate,
    'end_date': endDate,
    'timezone': timezone,
    'account_id': accountIds,
    'model': model,
    'useragent_group': userAgentGroup,
  };
}
