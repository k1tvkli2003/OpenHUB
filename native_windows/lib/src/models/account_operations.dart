import '../core/api/json_readers.dart';

class UsageTrendPoint {
  const UsageTrendPoint({required this.at, required this.value});

  final DateTime at;
  final double value;

  factory UsageTrendPoint.fromJson(Map<String, Object?> json) {
    final at = readNullableDateTime(json, 't', 'account.trend');
    if (at == null) {
      throw const FormatException('account.trend.t must not be null.');
    }
    return UsageTrendPoint(
      at: at,
      value: readNumber(json, 'v', 'account.trend').toDouble(),
    );
  }
}

class AccountTrends {
  const AccountTrends({
    required this.accountId,
    required this.primary,
    required this.secondary,
    required this.secondaryScheduled,
  });

  final String accountId;
  final List<UsageTrendPoint> primary;
  final List<UsageTrendPoint> secondary;
  final List<UsageTrendPoint> secondaryScheduled;

  factory AccountTrends.fromJson(Map<String, Object?> json) {
    List<UsageTrendPoint> points(String key, {bool optional = false}) {
      final raw = json[key];
      if (raw == null && optional) {
        return const <UsageTrendPoint>[];
      }
      final values = readList(raw, 'account.trends.$key');
      if (values.length > 10000) {
        throw FormatException('account.trends.$key exceeds the safety limit.');
      }
      return values
          .map(
            (item) => UsageTrendPoint.fromJson(
              readObject(item, 'account.trends.$key[]'),
            ),
          )
          .toList(growable: false);
    }

    return AccountTrends(
      accountId: readString(json, 'accountId', 'account.trends'),
      primary: points('primary'),
      secondary: points('secondary'),
      secondaryScheduled: points('secondaryScheduled', optional: true),
    );
  }
}

class AccountUsageResetCredits {
  const AccountUsageResetCredits({
    required this.accountId,
    required this.availableCount,
  });

  final String accountId;
  final int availableCount;

  factory AccountUsageResetCredits.fromJson(Map<String, Object?> json) {
    final credits = readObject(
      json['rateLimitResetCredits'],
      'account.usageResetCredits.rateLimitResetCredits',
    );
    return AccountUsageResetCredits(
      accountId: readString(json, 'accountId', 'account.usageResetCredits'),
      availableCount: readInt(
        credits,
        'availableCount',
        'account.usageResetCredits.rateLimitResetCredits',
      ),
    );
  }
}

class AccountProbeResult {
  const AccountProbeResult({
    required this.status,
    required this.accountId,
    required this.probeStatusCode,
    required this.accountStatusBefore,
    required this.accountStatusAfter,
    this.primaryUsedPercentBefore,
    this.primaryUsedPercentAfter,
    this.secondaryUsedPercentBefore,
    this.secondaryUsedPercentAfter,
  });

  final String status;
  final String accountId;
  final int? probeStatusCode;
  final double? primaryUsedPercentBefore;
  final double? primaryUsedPercentAfter;
  final double? secondaryUsedPercentBefore;
  final double? secondaryUsedPercentAfter;
  final String accountStatusBefore;
  final String accountStatusAfter;

  factory AccountProbeResult.fromJson(Map<String, Object?> json) {
    return AccountProbeResult(
      status: readString(json, 'status', 'account.probe'),
      accountId: readString(json, 'accountId', 'account.probe'),
      probeStatusCode: readNullableNumber(
        json,
        'probeStatusCode',
        'account.probe',
      )?.toInt(),
      primaryUsedPercentBefore: readNullableNumber(
        json,
        'primaryUsedPercentBefore',
        'account.probe',
      )?.toDouble(),
      primaryUsedPercentAfter: readNullableNumber(
        json,
        'primaryUsedPercentAfter',
        'account.probe',
      )?.toDouble(),
      secondaryUsedPercentBefore: readNullableNumber(
        json,
        'secondaryUsedPercentBefore',
        'account.probe',
      )?.toDouble(),
      secondaryUsedPercentAfter: readNullableNumber(
        json,
        'secondaryUsedPercentAfter',
        'account.probe',
      )?.toDouble(),
      accountStatusBefore: readString(
        json,
        'accountStatusBefore',
        'account.probe',
      ),
      accountStatusAfter: readString(
        json,
        'accountStatusAfter',
        'account.probe',
      ),
    );
  }
}

class AccountUsageResetResult {
  const AccountUsageResetResult({
    required this.status,
    required this.accountId,
    required this.code,
    required this.windowsReset,
    required this.usageWritten,
    required this.accountStatusBefore,
    required this.accountStatusAfter,
  });

  final String status;
  final String accountId;
  final String code;
  final int windowsReset;
  final bool usageWritten;
  final String accountStatusBefore;
  final String accountStatusAfter;

  factory AccountUsageResetResult.fromJson(Map<String, Object?> json) {
    return AccountUsageResetResult(
      status: readString(json, 'status', 'account.usageReset'),
      accountId: readString(json, 'accountId', 'account.usageReset'),
      code: readString(json, 'code', 'account.usageReset'),
      windowsReset: readInt(json, 'windowsReset', 'account.usageReset'),
      usageWritten: readBool(json, 'usageWritten', 'account.usageReset'),
      accountStatusBefore: readString(
        json,
        'accountStatusBefore',
        'account.usageReset',
      ),
      accountStatusAfter: readString(
        json,
        'accountStatusAfter',
        'account.usageReset',
      ),
    );
  }
}

class AccountImportResult {
  const AccountImportResult({
    required this.accountId,
    required this.email,
    required this.planType,
    required this.status,
  });

  final String accountId;
  final String email;
  final String planType;
  final String status;

  factory AccountImportResult.fromJson(Map<String, Object?> json) {
    return AccountImportResult(
      accountId: readString(json, 'accountId', 'account.import'),
      email: readString(json, 'email', 'account.import'),
      planType: readString(json, 'planType', 'account.import'),
      status: readString(json, 'status', 'account.import'),
    );
  }
}

class OauthStartResult {
  const OauthStartResult({
    required this.method,
    this.flowId,
    this.authorizationUrl,
    this.callbackUrl,
    this.verificationUrl,
    this.userCode,
    this.deviceAuthId,
    this.intervalSeconds,
    this.expiresInSeconds,
  });

  final String method;
  final String? flowId;
  final String? authorizationUrl;
  final String? callbackUrl;
  final String? verificationUrl;
  final String? userCode;
  final String? deviceAuthId;
  final int? intervalSeconds;
  final int? expiresInSeconds;

  factory OauthStartResult.fromJson(Map<String, Object?> json) {
    return OauthStartResult(
      method: readString(json, 'method', 'oauth.start'),
      flowId: readNullableString(json, 'flowId', 'oauth.start'),
      authorizationUrl: readNullableString(
        json,
        'authorizationUrl',
        'oauth.start',
      ),
      callbackUrl: readNullableString(json, 'callbackUrl', 'oauth.start'),
      verificationUrl: readNullableString(
        json,
        'verificationUrl',
        'oauth.start',
      ),
      userCode: readNullableString(json, 'userCode', 'oauth.start'),
      deviceAuthId: readNullableString(json, 'deviceAuthId', 'oauth.start'),
      intervalSeconds: readNullableNumber(
        json,
        'intervalSeconds',
        'oauth.start',
      )?.toInt(),
      expiresInSeconds: readNullableNumber(
        json,
        'expiresInSeconds',
        'oauth.start',
      )?.toInt(),
    );
  }
}

class OauthStatusResult {
  const OauthStatusResult({required this.status, this.errorMessage});

  final String status;
  final String? errorMessage;

  bool get succeeded => status == 'success';
  bool get failed => status == 'error';

  factory OauthStatusResult.fromJson(Map<String, Object?> json) {
    return OauthStatusResult(
      status: readString(json, 'status', 'oauth.status'),
      errorMessage: readNullableString(json, 'errorMessage', 'oauth.status'),
    );
  }
}
