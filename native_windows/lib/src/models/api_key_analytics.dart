import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

class ApiKeyTrendPoint {
  const ApiKeyTrendPoint({required this.time, required this.value});

  final DateTime time;
  final double value;

  factory ApiKeyTrendPoint.fromJson(Map<String, Object?> json) {
    const context = 'apiKey.trends.point';
    final time = readNullableDateTime(json, 't', context);
    if (time == null) {
      throw const ApiSchemaException('API-key trend time must not be null.');
    }
    return ApiKeyTrendPoint(
      time: time,
      value: readNumber(json, 'v', context).toDouble(),
    );
  }
}

class ApiKeyTrends {
  const ApiKeyTrends({
    required this.keyId,
    required this.cost,
    required this.tokens,
  });

  final String keyId;
  final List<ApiKeyTrendPoint> cost;
  final List<ApiKeyTrendPoint> tokens;

  factory ApiKeyTrends.fromJson(Map<String, Object?> json) {
    const context = 'apiKey.trends';
    final cost = _readTrend(json['cost'], '$context.cost');
    final tokens = _readTrend(json['tokens'], '$context.tokens');
    return ApiKeyTrends(
      keyId: readString(json, 'keyId', context),
      cost: cost,
      tokens: tokens,
    );
  }
}

class ApiKeyAccountCost {
  const ApiKeyAccountCost({
    required this.accountId,
    required this.email,
    required this.costUsd,
    required this.isDeleted,
  });

  final String? accountId;
  final String? email;
  final double costUsd;
  final bool isDeleted;

  factory ApiKeyAccountCost.fromJson(Map<String, Object?> json) {
    const context = 'apiKey.usage7d.accountCosts[]';
    return ApiKeyAccountCost(
      accountId: readNullableString(json, 'accountId', context),
      email: readNullableString(json, 'email', context),
      costUsd: readNumber(json, 'costUsd', context).toDouble(),
      isDeleted: readBool(json, 'isDeleted', context, fallback: false),
    );
  }
}

class ApiKeyUsage7Day {
  const ApiKeyUsage7Day({
    required this.keyId,
    required this.totalTokens,
    required this.totalCostUsd,
    required this.totalRequests,
    required this.cachedInputTokens,
    required this.accountCosts,
  });

  final String keyId;
  final int totalTokens;
  final double totalCostUsd;
  final int totalRequests;
  final int cachedInputTokens;
  final List<ApiKeyAccountCost> accountCosts;

  factory ApiKeyUsage7Day.fromJson(Map<String, Object?> json) {
    const context = 'apiKey.usage7d';
    final accountCosts =
        readList(
              json['accountCosts'] ?? const <Object?>[],
              '$context.accountCosts',
            )
            .map(
              (item) => ApiKeyAccountCost.fromJson(
                readObject(item, '$context.accountCosts[]'),
              ),
            )
            .toList(growable: false);
    if (accountCosts.length > 5000) {
      throw const ApiSchemaException(
        'API-key account-cost rows exceed the native safety limit.',
      );
    }
    return ApiKeyUsage7Day(
      keyId: readString(json, 'keyId', context),
      totalTokens: readInt(json, 'totalTokens', context),
      totalCostUsd: readNumber(json, 'totalCostUsd', context).toDouble(),
      totalRequests: readInt(json, 'totalRequests', context),
      cachedInputTokens: readInt(json, 'cachedInputTokens', context),
      accountCosts: accountCosts,
    );
  }
}

class ApiKeyAnalytics {
  const ApiKeyAnalytics({required this.trends, required this.usage7Day});

  final ApiKeyTrends trends;
  final ApiKeyUsage7Day usage7Day;

  DateTime? get latestSampleAt {
    DateTime? latest;
    for (final point in <ApiKeyTrendPoint>[...trends.cost, ...trends.tokens]) {
      if (latest == null || point.time.isAfter(latest)) {
        latest = point.time;
      }
    }
    return latest;
  }
}

List<ApiKeyTrendPoint> _readTrend(Object? value, String context) {
  final points = readList(value, context)
      .map((item) => ApiKeyTrendPoint.fromJson(readObject(item, '$context[]')))
      .toList(growable: false);
  if (points.length > 10000) {
    throw const ApiSchemaException(
      'API-key trend points exceed the native safety limit.',
    );
  }
  return points;
}
