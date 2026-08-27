import 'dart:collection';

import '../core/api/api_exception.dart';
import '../core/api/json_readers.dart';

class DashboardSettings {
  DashboardSettings._(Map<String, Object?> values)
    : values = UnmodifiableMapView<String, Object?>(values);

  final Map<String, Object?> values;

  int get version => intValue('version');
  String get routingStrategy => stringValue('routingStrategy');

  bool boolValue(String key) {
    final value = values[key];
    if (value is! bool) {
      throw ApiSchemaException('settings.$key must be a boolean.');
    }
    return value;
  }

  String stringValue(String key) {
    final value = values[key];
    if (value is! String) {
      throw ApiSchemaException('settings.$key must be a string.');
    }
    return value;
  }

  String? nullableStringValue(String key) {
    final value = values[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ApiSchemaException('settings.$key must be a string or null.');
    }
    return value;
  }

  int intValue(String key) {
    final value = values[key];
    if (value is! num || value != value.roundToDouble()) {
      throw ApiSchemaException('settings.$key must be an integer.');
    }
    return value.toInt();
  }

  int? nullableIntValue(String key) {
    final value = values[key];
    if (value == null) {
      return null;
    }
    if (value is! num || value != value.roundToDouble()) {
      throw ApiSchemaException('settings.$key must be an integer or null.');
    }
    return value.toInt();
  }

  double numberValue(String key) {
    final value = values[key];
    if (value is! num) {
      throw ApiSchemaException('settings.$key must be a number.');
    }
    return value.toDouble();
  }

  factory DashboardSettings.fromJson(Map<String, Object?> json) {
    const requiredBooleanKeys = <String>[
      'stickyThreadsEnabled',
      'prohibitFastMode',
      'upstreamProxyRoutingEnabled',
      'preferEarlierResetAccounts',
      'showResetCreditBadges',
      'autoRedeemResetCreditsBeforeExpiry',
      'showResetCreditExpiryBadge',
      'httpResponsesSessionBridgeGatewaySafeMode',
      'importWithoutOverwrite',
      'totpRequiredOnLogin',
      'totpConfigured',
      'apiKeyAuthEnabled',
      'hideUpstreamQuotaFromApiKeys',
      'limitWarmupEnabled',
      'limitWarmupStaggeredIdleEnabled',
      'guestAccessEnabled',
      'guestPasswordConfigured',
    ];
    const requiredStringKeys = <String>[
      'upstreamStreamTransport',
      'httpDownstreamTransportPolicy',
      'preferEarlierResetWindow',
      'routingStrategy',
      'warmupModel',
      'limitWarmupWindows',
      'limitWarmupModel',
      'limitWarmupPrompt',
      'weeklyPaceWorkingDays',
    ];
    const requiredIntegerKeys = <String>[
      'proxyAccountResponseCreateLimit',
      'proxyAccountStreamLimit',
      'proxyAccountStreamRecoveryReserve',
      'relativeAvailabilityTopK',
      'openaiCacheAffinityMaxAgeSeconds',
      'dashboardSessionTtlSeconds',
      'httpResponsesSessionBridgePromptCacheIdleTtlSeconds',
      'limitWarmupCooldownSeconds',
      'weeklyPaceSmoothingMinutes',
      'requestLogRetentionDays',
      'usageHistoryRetentionDays',
      'version',
    ];
    const requiredNumberKeys = <String>[
      'relativeAvailabilityPower',
      'stickyReallocationBudgetThresholdPct',
      'stickyReallocationPrimaryBudgetThresholdPct',
      'stickyReallocationSecondaryBudgetThresholdPct',
      'limitWarmupExhaustedThresholdPercent',
      'limitWarmupIdleThresholdPercent',
      'limitWarmupMinAvailablePercent',
    ];
    for (final key in requiredBooleanKeys) {
      readBool(json, key, 'settings');
    }
    for (final key in requiredStringKeys) {
      readString(json, key, 'settings');
    }
    for (final key in requiredIntegerKeys) {
      readInt(json, key, 'settings');
    }
    for (final key in requiredNumberKeys) {
      readNumber(json, key, 'settings');
    }
    readNullableString(json, 'upstreamProxyDefaultPoolId', 'settings');
    readNullableString(json, 'singleAccountId', 'settings');
    readNullableNumber(json, 'requestLogRetentionOverrideDays', 'settings');
    readNullableNumber(json, 'usageHistoryRetentionOverrideDays', 'settings');
    return DashboardSettings._(Map<String, Object?>.of(json));
  }
}

class UpstreamProxyEndpoint {
  const UpstreamProxyEndpoint({
    required this.id,
    required this.name,
    required this.scheme,
    required this.host,
    required this.port,
    required this.username,
    required this.isActive,
  });

  final String id;
  final String name;
  final String scheme;
  final String host;
  final int port;
  final String? username;
  final bool isActive;

  factory UpstreamProxyEndpoint.fromJson(Map<String, Object?> json) {
    const context = 'upstreamProxy.endpoints[]';
    return UpstreamProxyEndpoint(
      id: readString(json, 'id', context),
      name: readString(json, 'name', context),
      scheme: readString(json, 'scheme', context),
      host: readString(json, 'host', context),
      port: readInt(json, 'port', context),
      username: readNullableString(json, 'username', context),
      isActive: readBool(json, 'isActive', context),
    );
  }
}

class UpstreamProxyPool {
  const UpstreamProxyPool({
    required this.id,
    required this.name,
    required this.isActive,
    required this.endpointIds,
  });

  final String id;
  final String name;
  final bool isActive;
  final List<String> endpointIds;

  factory UpstreamProxyPool.fromJson(Map<String, Object?> json) {
    const context = 'upstreamProxy.pools[]';
    return UpstreamProxyPool(
      id: readString(json, 'id', context),
      name: readString(json, 'name', context),
      isActive: readBool(json, 'isActive', context),
      endpointIds: _readStringList(json['endpointIds'], '$context.endpointIds'),
    );
  }
}

class AccountProxyBinding {
  const AccountProxyBinding({
    required this.accountId,
    required this.poolId,
    required this.isActive,
  });

  final String accountId;
  final String poolId;
  final bool isActive;

  factory AccountProxyBinding.fromJson(Map<String, Object?> json) {
    const context = 'upstreamProxy.bindings[]';
    return AccountProxyBinding(
      accountId: readString(json, 'accountId', context),
      poolId: readString(json, 'poolId', context),
      isActive: readBool(json, 'isActive', context),
    );
  }
}

class UpstreamProxyAdmin {
  const UpstreamProxyAdmin({
    required this.routingEnabled,
    required this.defaultPoolId,
    required this.endpoints,
    required this.pools,
    required this.bindings,
  });

  final bool routingEnabled;
  final String? defaultPoolId;
  final List<UpstreamProxyEndpoint> endpoints;
  final List<UpstreamProxyPool> pools;
  final List<AccountProxyBinding> bindings;

  factory UpstreamProxyAdmin.fromJson(Map<String, Object?> json) {
    final endpoints = readList(json['endpoints'], 'upstreamProxy.endpoints')
        .map(
          (item) => UpstreamProxyEndpoint.fromJson(
            readObject(item, 'upstreamProxy.endpoints[]'),
          ),
        )
        .toList(growable: false);
    final pools = readList(json['pools'], 'upstreamProxy.pools')
        .map(
          (item) => UpstreamProxyPool.fromJson(
            readObject(item, 'upstreamProxy.pools[]'),
          ),
        )
        .toList(growable: false);
    final bindings = readList(json['bindings'], 'upstreamProxy.bindings')
        .map(
          (item) => AccountProxyBinding.fromJson(
            readObject(item, 'upstreamProxy.bindings[]'),
          ),
        )
        .toList(growable: false);
    if (endpoints.length > 1000 ||
        pools.length > 1000 ||
        bindings.length > 10000) {
      throw const ApiSchemaException(
        'Upstream proxy response exceeds native limits.',
      );
    }
    return UpstreamProxyAdmin(
      routingEnabled: readBool(json, 'routingEnabled', 'upstreamProxy'),
      defaultPoolId: readNullableString(json, 'defaultPoolId', 'upstreamProxy'),
      endpoints: endpoints,
      pools: pools,
      bindings: bindings,
    );
  }
}

class UpstreamProxyTestResult {
  const UpstreamProxyTestResult({
    required this.endpointId,
    required this.ok,
    required this.statusCode,
    required this.elapsedMs,
    required this.error,
  });

  final String endpointId;
  final bool ok;
  final int? statusCode;
  final int? elapsedMs;
  final String? error;

  factory UpstreamProxyTestResult.fromJson(Map<String, Object?> json) {
    const context = 'upstreamProxy.test';
    return UpstreamProxyTestResult(
      endpointId: readString(json, 'endpointId', context),
      ok: readBool(json, 'ok', context),
      statusCode: readNullableNumber(json, 'statusCode', context)?.toInt(),
      elapsedMs: readNullableNumber(json, 'elapsedMs', context)?.toInt(),
      error: readNullableString(json, 'error', context),
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
