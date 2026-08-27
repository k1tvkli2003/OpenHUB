import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

class LimitRule {
  const LimitRule({
    required this.id,
    required this.limitType,
    required this.limitWindow,
    required this.maxValue,
    required this.currentValue,
    required this.modelFilter,
    required this.resetAt,
  });

  final int id;
  final String limitType;
  final String limitWindow;
  final int maxValue;
  final int currentValue;
  final String? modelFilter;
  final DateTime? resetAt;

  double get fraction =>
      maxValue <= 0 ? 0 : (currentValue / maxValue).clamp(0, 1);

  factory LimitRule.fromJson(Map<String, Object?> json) {
    const context = 'apiKey.limits[]';
    return LimitRule(
      id: readInt(json, 'id', context),
      limitType: readString(json, 'limitType', context),
      limitWindow: readString(json, 'limitWindow', context),
      maxValue: readInt(json, 'maxValue', context),
      currentValue: readInt(json, 'currentValue', context),
      modelFilter: readNullableString(json, 'modelFilter', context),
      resetAt: readNullableDateTime(json, 'resetAt', context),
    );
  }
}

class ApiKeyUsageSummary {
  const ApiKeyUsageSummary({
    required this.requestCount,
    required this.totalTokens,
    required this.cachedInputTokens,
    required this.totalCostUsd,
  });

  final int requestCount;
  final int totalTokens;
  final int cachedInputTokens;
  final double totalCostUsd;

  factory ApiKeyUsageSummary.fromJson(Map<String, Object?> json) {
    const context = 'apiKey.usageSummary';
    return ApiKeyUsageSummary(
      requestCount: readInt(json, 'requestCount', context),
      totalTokens: readInt(json, 'totalTokens', context),
      cachedInputTokens: readInt(json, 'cachedInputTokens', context),
      totalCostUsd: readNumber(json, 'totalCostUsd', context).toDouble(),
    );
  }
}

class ApiKeyInfo {
  const ApiKeyInfo({
    required this.id,
    required this.name,
    required this.keyPrefix,
    required this.allowedModels,
    required this.applyToCodexModel,
    required this.enforcedModel,
    required this.enforcedReasoningEffort,
    required this.enforcedServiceTier,
    required this.trafficClass,
    required this.transportPolicyOverride,
    required this.usageSections,
    required this.expiresAt,
    required this.isActive,
    required this.accountAssignmentScopeEnabled,
    required this.sourceAssignmentScopeEnabled,
    required this.assignedAccountIds,
    required this.assignedSourceIds,
    required this.createdAt,
    required this.lastUsedAt,
    required this.limits,
    required this.usageSummary,
    required this.pooledRemainingPercentPrimary,
    required this.pooledRemainingPercentSecondary,
    required this.pooledCapacityCreditsPrimary,
  });

  final String id;
  final String name;
  final String keyPrefix;
  final List<String>? allowedModels;
  final bool applyToCodexModel;
  final String? enforcedModel;
  final String? enforcedReasoningEffort;
  final String? enforcedServiceTier;
  final String trafficClass;
  final String? transportPolicyOverride;
  final String usageSections;
  final DateTime? expiresAt;
  final bool isActive;
  final bool accountAssignmentScopeEnabled;
  final bool sourceAssignmentScopeEnabled;
  final List<String> assignedAccountIds;
  final List<String> assignedSourceIds;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final List<LimitRule> limits;
  final ApiKeyUsageSummary? usageSummary;
  final double? pooledRemainingPercentPrimary;
  final double? pooledRemainingPercentSecondary;
  final double pooledCapacityCreditsPrimary;

  bool get isExpired => expiresAt?.isBefore(DateTime.now().toUtc()) ?? false;

  factory ApiKeyInfo.fromJson(Map<String, Object?> json) {
    const context = 'apiKey';
    final createdAt = readNullableDateTime(json, 'createdAt', context);
    if (createdAt == null) {
      throw const ApiSchemaException('apiKey.createdAt must not be null.');
    }
    final allowed = json['allowedModels'];
    final limits =
        readList(json['limits'] ?? const <Object?>[], '$context.limits')
            .map(
              (item) =>
                  LimitRule.fromJson(readObject(item, '$context.limits[]')),
            )
            .toList(growable: false);
    if (limits.length > 1000) {
      throw const ApiSchemaException(
        'API key limit count exceeds native limits.',
      );
    }
    return ApiKeyInfo(
      id: readString(json, 'id', context),
      name: readString(json, 'name', context),
      keyPrefix: readString(json, 'keyPrefix', context),
      allowedModels: allowed == null
          ? null
          : readList(allowed, '$context.allowedModels')
                .map((item) {
                  if (item is! String) {
                    throw const ApiSchemaException(
                      'apiKey.allowedModels[] must be a string.',
                    );
                  }
                  return item;
                })
                .toList(growable: false),
      applyToCodexModel: readBool(
        json,
        'applyToCodexModel',
        context,
        fallback: false,
      ),
      enforcedModel: readNullableString(json, 'enforcedModel', context),
      enforcedReasoningEffort: readNullableString(
        json,
        'enforcedReasoningEffort',
        context,
      ),
      enforcedServiceTier: readNullableString(
        json,
        'enforcedServiceTier',
        context,
      ),
      trafficClass:
          readNullableString(json, 'trafficClass', context) ?? 'foreground',
      transportPolicyOverride: readNullableString(
        json,
        'transportPolicyOverride',
        context,
      ),
      usageSections:
          readNullableString(json, 'usageSections', context) ??
          'upstream_limits,account_pool_usage',
      expiresAt: readNullableDateTime(json, 'expiresAt', context),
      isActive: readBool(json, 'isActive', context),
      accountAssignmentScopeEnabled: readBool(
        json,
        'accountAssignmentScopeEnabled',
        context,
        fallback: false,
      ),
      sourceAssignmentScopeEnabled: readBool(
        json,
        'sourceAssignmentScopeEnabled',
        context,
        fallback: false,
      ),
      assignedAccountIds: _readStringList(
        json['assignedAccountIds'] ?? const <Object?>[],
        '$context.assignedAccountIds',
      ),
      assignedSourceIds: _readStringList(
        json['assignedSourceIds'] ?? const <Object?>[],
        '$context.assignedSourceIds',
      ),
      createdAt: createdAt,
      lastUsedAt: readNullableDateTime(json, 'lastUsedAt', context),
      limits: limits,
      usageSummary: json['usageSummary'] == null
          ? null
          : ApiKeyUsageSummary.fromJson(
              readObject(json['usageSummary'], '$context.usageSummary'),
            ),
      pooledRemainingPercentPrimary: readNullableNumber(
        json,
        'pooledRemainingPercentPrimary',
        context,
      )?.toDouble(),
      pooledRemainingPercentSecondary: readNullableNumber(
        json,
        'pooledRemainingPercentSecondary',
        context,
      )?.toDouble(),
      pooledCapacityCreditsPrimary:
          readNullableNumber(
            json,
            'pooledCapacityCreditsPrimary',
            context,
          )?.toDouble() ??
          0,
    );
  }
}

class ApiKeyCreateResult {
  const ApiKeyCreateResult({required this.info, required this.secret});

  final ApiKeyInfo info;
  final String secret;

  factory ApiKeyCreateResult.fromJson(Map<String, Object?> json) {
    return ApiKeyCreateResult(
      info: ApiKeyInfo.fromJson(json),
      secret: readString(json, 'key', 'apiKeyCreate'),
    );
  }
}

class ModelItem {
  const ModelItem({
    required this.id,
    required this.name,
    required this.sourceOnly,
    required this.supportedReasoningEfforts,
    required this.defaultReasoningEffort,
  });

  final String id;
  final String name;
  final bool sourceOnly;
  final List<String> supportedReasoningEfforts;
  final String? defaultReasoningEffort;

  factory ModelItem.fromJson(Map<String, Object?> json) {
    const context = 'models.models[]';
    return ModelItem(
      id: readString(json, 'id', context),
      name: readString(json, 'name', context),
      sourceOnly: readBool(json, 'sourceOnly', context, fallback: false),
      supportedReasoningEfforts: _readStringList(
        json['supportedReasoningEfforts'] ?? const <Object?>[],
        '$context.supportedReasoningEfforts',
      ),
      defaultReasoningEffort: readNullableString(
        json,
        'defaultReasoningEffort',
        context,
      ),
    );
  }
}

List<String> _readStringList(Object? value, String context) {
  return readList(value, context)
      .map((item) {
        if (item is! String) {
          throw ApiSchemaException('$context[] must be a string.');
        }
        return item;
      })
      .toList(growable: false);
}
