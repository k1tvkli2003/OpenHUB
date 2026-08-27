import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

class DepletionProjection {
  const DepletionProjection({
    required this.risk,
    required this.riskLevel,
    required this.burnRate,
    required this.safeUsagePercent,
    this.projectedExhaustionAt,
    this.secondsUntilExhaustion,
  });

  final double risk;
  final String riskLevel;
  final double burnRate;
  final double safeUsagePercent;
  final DateTime? projectedExhaustionAt;
  final double? secondsUntilExhaustion;

  factory DepletionProjection.fromJson(
    Map<String, Object?> json,
    String context,
  ) {
    return DepletionProjection(
      risk: readNumber(json, 'risk', context).toDouble(),
      riskLevel: readString(json, 'riskLevel', context),
      burnRate: readNumber(json, 'burnRate', context).toDouble(),
      safeUsagePercent: readNumber(
        json,
        'safeUsagePercent',
        context,
      ).toDouble(),
      projectedExhaustionAt: readNullableDateTime(
        json,
        'projectedExhaustionAt',
        context,
      ),
      secondsUntilExhaustion: readNullableNumber(
        json,
        'secondsUntilExhaustion',
        context,
      )?.toDouble(),
    );
  }
}

class WeeklyCreditPace {
  const WeeklyCreditPace({
    required this.actualUsedPercent,
    required this.scheduledUsedPercent,
    required this.deltaPercent,
    required this.status,
    required this.confidence,
    required this.accountCount,
    required this.staleAccountCount,
    required this.inactiveAccountCount,
    this.projectedDepletionHours,
    this.throttleToPercent,
    this.pauseForBreakEvenHours,
  });

  final double actualUsedPercent;
  final double scheduledUsedPercent;
  final double deltaPercent;
  final String status;
  final String confidence;
  final int accountCount;
  final int staleAccountCount;
  final int inactiveAccountCount;
  final double? projectedDepletionHours;
  final double? throttleToPercent;
  final double? pauseForBreakEvenHours;

  factory WeeklyCreditPace.fromJson(Map<String, Object?> json) {
    return WeeklyCreditPace(
      actualUsedPercent: readNumber(
        json,
        'actualUsedPercent',
        'dashboard.weeklyCreditPace',
      ).toDouble(),
      scheduledUsedPercent: readNumber(
        json,
        'scheduledUsedPercent',
        'dashboard.weeklyCreditPace',
      ).toDouble(),
      deltaPercent: readNumber(
        json,
        'deltaPercent',
        'dashboard.weeklyCreditPace',
      ).toDouble(),
      status: readString(json, 'status', 'dashboard.weeklyCreditPace'),
      confidence: readString(json, 'confidence', 'dashboard.weeklyCreditPace'),
      accountCount: readInt(json, 'accountCount', 'dashboard.weeklyCreditPace'),
      staleAccountCount:
          readNullableNumber(
            json,
            'staleAccountCount',
            'dashboard.weeklyCreditPace',
          )?.toInt() ??
          0,
      inactiveAccountCount:
          readNullableNumber(
            json,
            'inactiveAccountCount',
            'dashboard.weeklyCreditPace',
          )?.toInt() ??
          0,
      projectedDepletionHours: readNullableNumber(
        json,
        'projectedDepletionHours',
        'dashboard.weeklyCreditPace',
      )?.toDouble(),
      throttleToPercent: readNullableNumber(
        json,
        'throttleToPercent',
        'dashboard.weeklyCreditPace',
      )?.toDouble(),
      pauseForBreakEvenHours: readNullableNumber(
        json,
        'pauseForBreakEvenHours',
        'dashboard.weeklyCreditPace',
      )?.toDouble(),
    );
  }
}

class DashboardProjections {
  const DashboardProjections({
    this.primary,
    this.secondary,
    this.weeklyCreditPace,
  });

  final DepletionProjection? primary;
  final DepletionProjection? secondary;
  final WeeklyCreditPace? weeklyCreditPace;

  factory DashboardProjections.fromJson(Map<String, Object?> json) {
    final primary = readNullableObject(
      json,
      'depletionPrimary',
      'dashboard.projections',
    );
    final secondary = readNullableObject(
      json,
      'depletionSecondary',
      'dashboard.projections',
    );
    final pace = readNullableObject(
      json,
      'weeklyCreditPace',
      'dashboard.projections',
    );
    return DashboardProjections(
      primary: primary == null
          ? null
          : DepletionProjection.fromJson(
              primary,
              'dashboard.projections.depletionPrimary',
            ),
      secondary: secondary == null
          ? null
          : DepletionProjection.fromJson(
              secondary,
              'dashboard.projections.depletionSecondary',
            ),
      weeklyCreditPace: pace == null ? null : WeeklyCreditPace.fromJson(pace),
    );
  }
}

class RequestLogEntry {
  const RequestLogEntry({
    required this.requestedAt,
    required this.requestId,
    required this.model,
    required this.status,
    this.accountId,
    this.planType,
    this.apiKeyId,
    this.apiKeyName,
    this.requestKind = 'normal',
    this.conversationId,
    this.reasoningEffort,
    this.serviceTier,
    this.transport,
    this.errorCode,
    this.errorMessage,
    this.tokens,
    this.cachedInputTokens,
    this.costUsd,
    this.latencyMs,
    this.latencyFirstTokenMs,
    this.latencyQueueMs,
  });

  final DateTime requestedAt;
  final String requestId;
  final String model;
  final String status;
  final String? accountId;
  final String? planType;
  final String? apiKeyId;
  final String? apiKeyName;
  final String requestKind;
  final String? conversationId;
  final String? reasoningEffort;
  final String? serviceTier;
  final String? transport;
  final String? errorCode;
  final String? errorMessage;
  final int? tokens;
  final int? cachedInputTokens;
  final double? costUsd;
  final int? latencyMs;
  final int? latencyFirstTokenMs;
  final int? latencyQueueMs;

  factory RequestLogEntry.fromJson(Map<String, Object?> json) {
    final requestedAt = readNullableDateTime(json, 'requestedAt', 'requestLog');
    if (requestedAt == null) {
      throw const ApiSchemaException(
        'requestLog.requestedAt must not be null.',
      );
    }
    return RequestLogEntry(
      requestedAt: requestedAt,
      requestId: readString(json, 'requestId', 'requestLog'),
      model: readString(json, 'model', 'requestLog'),
      status: readString(json, 'status', 'requestLog'),
      accountId: readNullableString(json, 'accountId', 'requestLog'),
      planType: readNullableString(json, 'planType', 'requestLog'),
      apiKeyId: readNullableString(json, 'apiKeyId', 'requestLog'),
      apiKeyName: readNullableString(json, 'apiKeyName', 'requestLog'),
      requestKind:
          readNullableString(json, 'requestKind', 'requestLog') ?? 'normal',
      conversationId: readNullableString(json, 'conversationId', 'requestLog'),
      reasoningEffort: readNullableString(
        json,
        'reasoningEffort',
        'requestLog',
      ),
      serviceTier: readNullableString(json, 'serviceTier', 'requestLog'),
      transport: readNullableString(json, 'transport', 'requestLog'),
      errorCode: readNullableString(json, 'errorCode', 'requestLog'),
      errorMessage: readNullableString(json, 'errorMessage', 'requestLog'),
      tokens: readNullableNumber(json, 'tokens', 'requestLog')?.toInt(),
      cachedInputTokens: readNullableNumber(
        json,
        'cachedInputTokens',
        'requestLog',
      )?.toInt(),
      costUsd: readNullableNumber(json, 'costUsd', 'requestLog')?.toDouble(),
      latencyMs: readNullableNumber(json, 'latencyMs', 'requestLog')?.toInt(),
      latencyFirstTokenMs: readNullableNumber(
        json,
        'latencyFirstTokenMs',
        'requestLog',
      )?.toInt(),
      latencyQueueMs: readNullableNumber(
        json,
        'latencyQueueMs',
        'requestLog',
      )?.toInt(),
    );
  }
}

class RequestLogsPage {
  const RequestLogsPage({
    required this.requests,
    required this.total,
    required this.hasMore,
  });

  final List<RequestLogEntry> requests;
  final int total;
  final bool hasMore;

  factory RequestLogsPage.fromJson(Map<String, Object?> json) {
    final requests = readList(json['requests'], 'requestLogs.requests')
        .map(
          (item) => RequestLogEntry.fromJson(
            readObject(item, 'requestLogs.requests[]'),
          ),
        )
        .toList(growable: false);
    if (requests.length > 1000) {
      throw const ApiSchemaException(
        'Request-log page exceeds the native safety limit.',
      );
    }
    return RequestLogsPage(
      requests: requests,
      total: readInt(json, 'total', 'requestLogs'),
      hasMore: readBool(json, 'hasMore', 'requestLogs'),
    );
  }
}

class RequestLogModelOption {
  const RequestLogModelOption({required this.model, this.reasoningEffort});

  final String model;
  final String? reasoningEffort;

  String get encoded => '$model:::${reasoningEffort ?? ''}';
  String get label => reasoningEffort == null
      ? model
      : '$model · ${reasoningEffort!.replaceAll('_', ' ')}';

  factory RequestLogModelOption.fromJson(Map<String, Object?> json) {
    return RequestLogModelOption(
      model: readString(json, 'model', 'requestLogOption.model'),
      reasoningEffort: readNullableString(
        json,
        'reasoningEffort',
        'requestLogOption.model',
      ),
    );
  }
}

class RequestLogApiKeyOption {
  const RequestLogApiKeyOption({
    required this.id,
    required this.name,
    this.keyPrefix,
  });

  final String id;
  final String name;
  final String? keyPrefix;

  factory RequestLogApiKeyOption.fromJson(Map<String, Object?> json) {
    return RequestLogApiKeyOption(
      id: readString(json, 'id', 'requestLogOption.apiKey'),
      name: readString(json, 'name', 'requestLogOption.apiKey'),
      keyPrefix: readNullableString(
        json,
        'keyPrefix',
        'requestLogOption.apiKey',
      ),
    );
  }
}

class RequestLogOptions {
  const RequestLogOptions({
    required this.accountIds,
    required this.modelOptions,
    required this.apiKeys,
    required this.statuses,
  });

  final List<String> accountIds;
  final List<RequestLogModelOption> modelOptions;
  final List<RequestLogApiKeyOption> apiKeys;
  final List<String> statuses;

  factory RequestLogOptions.fromJson(Map<String, Object?> json) {
    List<String> strings(String key) =>
        readList(json[key], 'requestLogOptions.$key')
            .map((value) {
              if (value is! String) {
                throw ApiSchemaException(
                  'requestLogOptions.$key[] must be a string.',
                );
              }
              return value;
            })
            .toList(growable: false);

    return RequestLogOptions(
      accountIds: strings('accountIds'),
      modelOptions:
          readList(json['modelOptions'], 'requestLogOptions.modelOptions')
              .map(
                (item) => RequestLogModelOption.fromJson(
                  readObject(item, 'requestLogOptions.modelOptions[]'),
                ),
              )
              .toList(growable: false),
      apiKeys: readList(json['apiKeys'], 'requestLogOptions.apiKeys')
          .map(
            (item) => RequestLogApiKeyOption.fromJson(
              readObject(item, 'requestLogOptions.apiKeys[]'),
            ),
          )
          .toList(growable: false),
      statuses: strings('statuses'),
    );
  }
}

class RequestLogsQuery {
  const RequestLogsQuery({
    this.limit = 25,
    this.offset = 0,
    this.search = '',
    this.timeframe = 'all',
    this.accountIds = const <String>[],
    this.apiKeyIds = const <String>[],
    this.modelOptions = const <String>[],
    this.statuses = const <String>[],
    this.conversationId,
  });

  final int limit;
  final int offset;
  final String search;
  final String timeframe;
  final List<String> accountIds;
  final List<String> apiKeyIds;
  final List<String> modelOptions;
  final List<String> statuses;
  final String? conversationId;

  Map<String, Object?> toQuery() {
    final since = switch (timeframe) {
      '1h' => DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      '24h' => DateTime.now().toUtc().subtract(const Duration(days: 1)),
      '7d' => DateTime.now().toUtc().subtract(const Duration(days: 7)),
      _ => null,
    };
    return <String, Object?>{
      'limit': limit.clamp(1, 1000),
      'offset': offset < 0 ? 0 : offset,
      'search': search.trim().isEmpty ? null : search.trim(),
      'accountId': accountIds,
      'apiKeyId': apiKeyIds,
      'modelOption': modelOptions,
      'status': statuses,
      'conversation_id': conversationId,
      'since': since?.toIso8601String(),
    };
  }

  RequestLogsQuery copyWith({
    int? limit,
    int? offset,
    String? search,
    String? timeframe,
    List<String>? accountIds,
    List<String>? apiKeyIds,
    List<String>? modelOptions,
    List<String>? statuses,
    String? conversationId,
    bool clearConversationId = false,
  }) {
    return RequestLogsQuery(
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      search: search ?? this.search,
      timeframe: timeframe ?? this.timeframe,
      accountIds: accountIds ?? this.accountIds,
      apiKeyIds: apiKeyIds ?? this.apiKeyIds,
      modelOptions: modelOptions ?? this.modelOptions,
      statuses: statuses ?? this.statuses,
      conversationId: clearConversationId
          ? null
          : conversationId ?? this.conversationId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RequestLogsQuery &&
        limit == other.limit &&
        offset == other.offset &&
        search == other.search &&
        timeframe == other.timeframe &&
        conversationId == other.conversationId &&
        _same(accountIds, other.accountIds) &&
        _same(apiKeyIds, other.apiKeyIds) &&
        _same(modelOptions, other.modelOptions) &&
        _same(statuses, other.statuses);
  }

  @override
  int get hashCode => Object.hash(
    limit,
    offset,
    search,
    timeframe,
    conversationId,
    Object.hashAll(accountIds),
    Object.hashAll(apiKeyIds),
    Object.hashAll(modelOptions),
    Object.hashAll(statuses),
  );
}

bool _same(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
