import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

class ModelSourceModel {
  const ModelSourceModel({
    required this.model,
    required this.displayName,
    required this.contextWindow,
    required this.maxOutputTokens,
    required this.supportsStreaming,
    required this.supportsTools,
    required this.supportsVision,
    required this.isEnabled,
  });

  final String model;
  final String? displayName;
  final int? contextWindow;
  final int? maxOutputTokens;
  final bool supportsStreaming;
  final bool supportsTools;
  final bool supportsVision;
  final bool isEnabled;

  factory ModelSourceModel.fromJson(Map<String, Object?> json) {
    const context = 'modelSources.sources[].models[]';
    return ModelSourceModel(
      model: readString(json, 'model', context),
      displayName: readNullableString(json, 'displayName', context),
      contextWindow: _readNullableInt(json, 'contextWindow', context),
      maxOutputTokens: _readNullableInt(json, 'maxOutputTokens', context),
      supportsStreaming: readBool(json, 'supportsStreaming', context),
      supportsTools: readBool(json, 'supportsTools', context),
      supportsVision: readBool(json, 'supportsVision', context),
      isEnabled: readBool(json, 'isEnabled', context),
    );
  }
}

class ModelSource {
  const ModelSource({
    required this.id,
    required this.name,
    required this.kind,
    required this.baseUrl,
    required this.isEnabled,
    required this.healthStatus,
    required this.supportsChatCompletions,
    required this.supportsResponses,
    required this.supportsAudioTranscriptions,
    required this.timeoutSeconds,
    required this.maxConcurrency,
    required this.models,
  });

  final String id;
  final String name;
  final String kind;
  final String baseUrl;
  final bool isEnabled;
  final String healthStatus;
  final bool supportsChatCompletions;
  final bool supportsResponses;
  final bool supportsAudioTranscriptions;
  final int? timeoutSeconds;
  final int? maxConcurrency;
  final List<ModelSourceModel> models;

  factory ModelSource.fromJson(Map<String, Object?> json) {
    const context = 'modelSources.sources[]';
    final models = readList(json['models'], '$context.models')
        .map(
          (item) =>
              ModelSourceModel.fromJson(readObject(item, '$context.models[]')),
        )
        .toList(growable: false);
    if (models.length > 5000) {
      throw const ApiSchemaException(
        'A model source exceeds the native model safety limit.',
      );
    }
    return ModelSource(
      id: readString(json, 'id', context),
      name: readString(json, 'name', context),
      kind: readString(json, 'kind', context),
      baseUrl: readString(json, 'baseUrl', context),
      isEnabled: readBool(json, 'isEnabled', context),
      healthStatus: readString(json, 'healthStatus', context),
      supportsChatCompletions: readBool(
        json,
        'supportsChatCompletions',
        context,
      ),
      supportsResponses: readBool(json, 'supportsResponses', context),
      supportsAudioTranscriptions: readBool(
        json,
        'supportsAudioTranscriptions',
        context,
      ),
      timeoutSeconds: _readNullableInt(json, 'timeoutSeconds', context),
      maxConcurrency: _readNullableInt(json, 'maxConcurrency', context),
      models: models,
    );
  }
}

class ModelSourcesCatalog {
  const ModelSourcesCatalog(this.sources);

  final List<ModelSource> sources;

  factory ModelSourcesCatalog.fromJson(Map<String, Object?> json) {
    final sources = readList(json['sources'], 'modelSources.sources')
        .map(
          (item) =>
              ModelSource.fromJson(readObject(item, 'modelSources.sources[]')),
        )
        .toList(growable: false);
    if (sources.length > 1000) {
      throw const ApiSchemaException(
        'Model source count exceeds the native safety limit.',
      );
    }
    return ModelSourcesCatalog(sources);
  }
}

class FirewallEntry {
  const FirewallEntry({required this.ipAddress, required this.createdAt});

  final String ipAddress;
  final DateTime createdAt;

  factory FirewallEntry.fromJson(Map<String, Object?> json) {
    const context = 'firewall.entries[]';
    return FirewallEntry(
      ipAddress: readString(json, 'ipAddress', context),
      createdAt: _readDateTime(json, 'createdAt', context),
    );
  }
}

class FirewallPolicy {
  const FirewallPolicy({required this.mode, required this.entries});

  final String mode;
  final List<FirewallEntry> entries;

  factory FirewallPolicy.fromJson(Map<String, Object?> json) {
    final mode = readString(json, 'mode', 'firewall');
    if (mode != 'allow_all' && mode != 'allowlist_active') {
      throw ApiSchemaException('Unsupported firewall mode: $mode');
    }
    final entries = readList(json['entries'], 'firewall.entries')
        .map(
          (item) =>
              FirewallEntry.fromJson(readObject(item, 'firewall.entries[]')),
        )
        .toList(growable: false);
    if (entries.length > 10000) {
      throw const ApiSchemaException(
        'Firewall entry count exceeds the native safety limit.',
      );
    }
    return FirewallPolicy(mode: mode, entries: entries);
  }
}

class QuotaPlannerSettings {
  const QuotaPlannerSettings({
    required this.mode,
    required this.timezone,
    required this.workingDays,
    required this.workingHoursStart,
    required this.workingHoursEnd,
    required this.prewarmEnabled,
    required this.prewarmLeadMinutes,
    required this.maxWarmupsPerDay,
    required this.maxWarmupCreditsPerDay,
    required this.minExpectedGain,
    required this.forecastQuantile,
    required this.allowSyntheticTraffic,
    required this.warmupModelPreference,
    required this.dryRun,
  });

  final String mode;
  final String timezone;
  final List<int> workingDays;
  final String workingHoursStart;
  final String workingHoursEnd;
  final bool prewarmEnabled;
  final int prewarmLeadMinutes;
  final int maxWarmupsPerDay;
  final double maxWarmupCreditsPerDay;
  final double minExpectedGain;
  final String forecastQuantile;
  final bool allowSyntheticTraffic;
  final String? warmupModelPreference;
  final bool dryRun;

  factory QuotaPlannerSettings.fromJson(Map<String, Object?> json) {
    const context = 'quotaPlanner.settings';
    final mode = readString(json, 'mode', context);
    if (!const {'off', 'shadow', 'suggest', 'auto'}.contains(mode)) {
      throw ApiSchemaException('Unsupported quota planner mode: $mode');
    }
    final quantile = readString(json, 'forecastQuantile', context);
    if (!const {'p50', 'p75', 'p90'}.contains(quantile)) {
      throw ApiSchemaException('Unsupported quota planner quantile: $quantile');
    }
    final workingDays = readList(json['workingDays'], '$context.workingDays')
        .map((item) {
          if (item is! num || item != item.roundToDouble()) {
            throw const ApiSchemaException(
              'quotaPlanner.settings.workingDays[] must be an integer.',
            );
          }
          final day = item.toInt();
          if (day < 0 || day > 6) {
            throw const ApiSchemaException(
              'quotaPlanner.settings.workingDays[] must be from 0 through 6.',
            );
          }
          return day;
        })
        .toList(growable: false);
    return QuotaPlannerSettings(
      mode: mode,
      timezone: readString(json, 'timezone', context),
      workingDays: workingDays,
      workingHoursStart: readString(json, 'workingHoursStart', context),
      workingHoursEnd: readString(json, 'workingHoursEnd', context),
      prewarmEnabled: readBool(json, 'prewarmEnabled', context),
      prewarmLeadMinutes: readInt(json, 'prewarmLeadMinutes', context),
      maxWarmupsPerDay: readInt(json, 'maxWarmupsPerDay', context),
      maxWarmupCreditsPerDay: readNumber(
        json,
        'maxWarmupCreditsPerDay',
        context,
      ).toDouble(),
      minExpectedGain: readNumber(json, 'minExpectedGain', context).toDouble(),
      forecastQuantile: quantile,
      allowSyntheticTraffic: readBool(json, 'allowSyntheticTraffic', context),
      warmupModelPreference: readNullableString(
        json,
        'warmupModelPreference',
        context,
      ),
      dryRun: readBool(json, 'dryRun', context),
    );
  }
}

class QuotaPlannerDecision {
  const QuotaPlannerDecision({
    required this.id,
    required this.createdAt,
    required this.mode,
    required this.accountId,
    required this.action,
    required this.scheduledAt,
    required this.executedAt,
    required this.score,
    required this.reason,
    required this.status,
  });

  final String id;
  final DateTime createdAt;
  final String mode;
  final String? accountId;
  final String action;
  final DateTime? scheduledAt;
  final DateTime? executedAt;
  final double score;
  final String? reason;
  final String status;

  factory QuotaPlannerDecision.fromJson(Map<String, Object?> json) {
    const context = 'quotaPlanner.decisions[]';
    return QuotaPlannerDecision(
      id: readString(json, 'id', context),
      createdAt: _readDateTime(json, 'createdAt', context),
      mode: readString(json, 'mode', context),
      accountId: readNullableString(json, 'accountId', context),
      action: readString(json, 'action', context),
      scheduledAt: readNullableDateTime(json, 'scheduledAt', context),
      executedAt: readNullableDateTime(json, 'executedAt', context),
      score: readNumber(json, 'score', context).toDouble(),
      reason: readNullableString(json, 'reason', context),
      status: readString(json, 'status', context),
    );
  }
}

class QuotaPlannerSimulation {
  const QuotaPlannerSimulation({
    required this.loss,
    required this.unmetDemand,
    required this.wastedCapacity,
    required this.forecastUnits,
    required this.servedUnits,
  });

  final double loss;
  final double unmetDemand;
  final double wastedCapacity;
  final double forecastUnits;
  final double servedUnits;

  factory QuotaPlannerSimulation.fromJson(Map<String, Object?> json) {
    const context = 'quotaPlanner.forecast.simulation';
    return QuotaPlannerSimulation(
      loss: readNumber(json, 'loss', context).toDouble(),
      unmetDemand: readNumber(json, 'unmetDemand', context).toDouble(),
      wastedCapacity: readNumber(json, 'wastedCapacity', context).toDouble(),
      forecastUnits: readNumber(json, 'forecastUnits', context).toDouble(),
      servedUnits: readNumber(json, 'servedUnits', context).toDouble(),
    );
  }
}

class QuotaPlannerForecast {
  const QuotaPlannerForecast({
    required this.generatedAt,
    required this.horizonHours,
    required this.totalDemandUnits,
    required this.peakSlotStart,
    required this.peakDemandUnits,
    required this.simulation,
    required this.slotCount,
  });

  final DateTime generatedAt;
  final int horizonHours;
  final double totalDemandUnits;
  final DateTime? peakSlotStart;
  final double peakDemandUnits;
  final QuotaPlannerSimulation simulation;
  final int slotCount;

  factory QuotaPlannerForecast.fromJson(Map<String, Object?> json) {
    const context = 'quotaPlanner.forecast';
    final slots = readList(json['slots'], '$context.slots');
    if (slots.length > 10000) {
      throw const ApiSchemaException(
        'Quota forecast exceeds the native slot safety limit.',
      );
    }
    for (final item in slots) {
      final slot = readObject(item, '$context.slots[]');
      _readDateTime(slot, 'slotStart', '$context.slots[]');
      readNumber(slot, 'demandUnits', '$context.slots[]');
      readNumber(slot, 'requestCount', '$context.slots[]');
      readString(slot, 'source', '$context.slots[]');
    }
    return QuotaPlannerForecast(
      generatedAt: _readDateTime(json, 'generatedAt', context),
      horizonHours: readInt(json, 'horizonHours', context),
      totalDemandUnits: readNumber(
        json,
        'totalDemandUnits',
        context,
      ).toDouble(),
      peakSlotStart: readNullableDateTime(json, 'peakSlotStart', context),
      peakDemandUnits: readNumber(json, 'peakDemandUnits', context).toDouble(),
      simulation: QuotaPlannerSimulation.fromJson(
        readObject(json['simulation'], '$context.simulation'),
      ),
      slotCount: slots.length,
    );
  }
}

class QuotaPlannerSnapshot {
  const QuotaPlannerSnapshot({
    required this.settings,
    required this.decisions,
    required this.forecast,
  });

  final QuotaPlannerSettings settings;
  final List<QuotaPlannerDecision> decisions;
  final QuotaPlannerForecast forecast;
}

class QuotaPlannerActionResult {
  const QuotaPlannerActionResult({
    required this.decisionId,
    required this.status,
    required this.reason,
  });

  final String decisionId;
  final String status;
  final String reason;

  factory QuotaPlannerActionResult.fromJson(Map<String, Object?> json) {
    const context = 'quotaPlanner.action';
    return QuotaPlannerActionResult(
      decisionId: readString(json, 'decisionId', context),
      status: readString(json, 'status', context),
      reason: readString(json, 'reason', context),
    );
  }
}

class StickySessionsQuery {
  const StickySessionsQuery({
    this.staleOnly = false,
    this.accountQuery = '',
    this.keyQuery = '',
    this.sortBy = 'updated_at',
    this.sortDir = 'desc',
    this.offset = 0,
    this.limit = 50,
  });

  final bool staleOnly;
  final String accountQuery;
  final String keyQuery;
  final String sortBy;
  final String sortDir;
  final int offset;
  final int limit;

  Map<String, Object?> toQuery() => <String, Object?>{
    'staleOnly': staleOnly,
    if (accountQuery.trim().isNotEmpty) 'accountQuery': accountQuery.trim(),
    if (keyQuery.trim().isNotEmpty) 'keyQuery': keyQuery.trim(),
    'sortBy': sortBy,
    'sortDir': sortDir,
    'offset': offset,
    'limit': limit,
  };

  StickySessionsQuery copyWith({
    bool? staleOnly,
    String? accountQuery,
    String? keyQuery,
    String? sortBy,
    String? sortDir,
    int? offset,
    int? limit,
  }) => StickySessionsQuery(
    staleOnly: staleOnly ?? this.staleOnly,
    accountQuery: accountQuery ?? this.accountQuery,
    keyQuery: keyQuery ?? this.keyQuery,
    sortBy: sortBy ?? this.sortBy,
    sortDir: sortDir ?? this.sortDir,
    offset: offset ?? this.offset,
    limit: limit ?? this.limit,
  );
}

class StickySessionEntry {
  const StickySessionEntry({
    required this.key,
    required this.displayName,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.isStale,
  });

  final String key;
  final String displayName;
  final String kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final bool isStale;

  factory StickySessionEntry.fromJson(Map<String, Object?> json) {
    const context = 'stickySessions.entries[]';
    return StickySessionEntry(
      key: readString(json, 'key', context),
      displayName: readString(json, 'displayName', context),
      kind: readString(json, 'kind', context),
      createdAt: _readDateTime(json, 'createdAt', context),
      updatedAt: _readDateTime(json, 'updatedAt', context),
      expiresAt: readNullableDateTime(json, 'expiresAt', context),
      isStale: readBool(json, 'isStale', context),
    );
  }
}

class StickySessionsPage {
  const StickySessionsPage({
    required this.entries,
    required this.stalePromptCacheCount,
    required this.total,
    required this.hasMore,
  });

  final List<StickySessionEntry> entries;
  final int stalePromptCacheCount;
  final int total;
  final bool hasMore;

  factory StickySessionsPage.fromJson(Map<String, Object?> json) {
    const context = 'stickySessions';
    final entries = readList(json['entries'], '$context.entries')
        .map(
          (item) => StickySessionEntry.fromJson(
            readObject(item, '$context.entries[]'),
          ),
        )
        .toList(growable: false);
    if (entries.length > 500) {
      throw const ApiSchemaException(
        'Sticky session page exceeds the native safety limit.',
      );
    }
    return StickySessionsPage(
      entries: entries,
      stalePromptCacheCount: readInt(json, 'stalePromptCacheCount', context),
      total: readInt(json, 'total', context),
      hasMore: readBool(json, 'hasMore', context),
    );
  }
}

class TotpSetupResult {
  const TotpSetupResult({
    required this.secret,
    required this.otpauthUri,
    required this.qrSvgDataUri,
  });

  final String secret;
  final String otpauthUri;
  final String qrSvgDataUri;

  factory TotpSetupResult.fromJson(Map<String, Object?> json) {
    const context = 'auth.totpSetup';
    return TotpSetupResult(
      secret: readString(json, 'secret', context),
      otpauthUri: readString(json, 'otpauthUri', context),
      qrSvgDataUri: readString(json, 'qrSvgDataUri', context),
    );
  }
}

DateTime _readDateTime(Map<String, Object?> json, String key, String context) {
  final value = readString(json, key, context);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw ApiSchemaException('$context.$key is not a valid ISO-8601 date.');
  }
  return parsed.toUtc();
}

int? _readNullableInt(Map<String, Object?> json, String key, String context) {
  final value = readNullableNumber(json, key, context);
  if (value == null) {
    return null;
  }
  if (value != value.roundToDouble()) {
    throw ApiSchemaException('$context.$key must be an integer or null.');
  }
  return value.toInt();
}
