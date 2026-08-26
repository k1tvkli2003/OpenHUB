import '../core/api/json_readers.dart';

class AccountUsage {
  const AccountUsage({
    this.primaryRemainingPercent,
    this.secondaryRemainingPercent,
    this.monthlyRemainingPercent,
  });

  final double? primaryRemainingPercent;
  final double? secondaryRemainingPercent;
  final double? monthlyRemainingPercent;

  factory AccountUsage.fromJson(Map<String, Object?> json) {
    return AccountUsage(
      primaryRemainingPercent: readNullableNumber(
        json,
        'primaryRemainingPercent',
        'account.usage',
      )?.toDouble(),
      secondaryRemainingPercent: readNullableNumber(
        json,
        'secondaryRemainingPercent',
        'account.usage',
      )?.toDouble(),
      monthlyRemainingPercent: readNullableNumber(
        json,
        'monthlyRemainingPercent',
        'account.usage',
      )?.toDouble(),
    );
  }
}

class AccountRequestUsage {
  const AccountRequestUsage({
    required this.requestCount,
    required this.totalTokens,
    required this.cachedInputTokens,
    required this.totalCostUsd,
  });

  final int requestCount;
  final int totalTokens;
  final int cachedInputTokens;
  final double totalCostUsd;

  factory AccountRequestUsage.fromJson(Map<String, Object?> json) {
    return AccountRequestUsage(
      requestCount: readInt(json, 'requestCount', 'account.requestUsage'),
      totalTokens: readInt(json, 'totalTokens', 'account.requestUsage'),
      cachedInputTokens: readInt(
        json,
        'cachedInputTokens',
        'account.requestUsage',
      ),
      totalCostUsd: readNumber(
        json,
        'totalCostUsd',
        'account.requestUsage',
      ).toDouble(),
    );
  }
}

class AccountTokenStatus {
  const AccountTokenStatus({this.expiresAt, this.state});

  final DateTime? expiresAt;
  final String? state;

  factory AccountTokenStatus.fromJson(Map<String, Object?> json) {
    return AccountTokenStatus(
      expiresAt: readNullableDateTime(json, 'expiresAt', 'account.auth.token'),
      state: readNullableString(json, 'state', 'account.auth.token'),
    );
  }
}

class AccountAuthStatus {
  const AccountAuthStatus({this.access, this.refresh, this.idToken});

  final AccountTokenStatus? access;
  final AccountTokenStatus? refresh;
  final AccountTokenStatus? idToken;

  factory AccountAuthStatus.fromJson(Map<String, Object?> json) {
    AccountTokenStatus? token(String key) {
      final value = readNullableObject(json, key, 'account.auth');
      return value == null ? null : AccountTokenStatus.fromJson(value);
    }

    return AccountAuthStatus(
      access: token('access'),
      refresh: token('refresh'),
      idToken: token('idToken'),
    );
  }
}

class AccountAdditionalQuota {
  const AccountAdditionalQuota({
    required this.limitName,
    required this.meteredFeature,
    this.displayLabel,
    this.routingPolicy,
  });

  final String limitName;
  final String meteredFeature;
  final String? displayLabel;
  final String? routingPolicy;

  factory AccountAdditionalQuota.fromJson(Map<String, Object?> json) {
    return AccountAdditionalQuota(
      limitName: readString(json, 'limitName', 'account.additionalQuota'),
      meteredFeature: readString(
        json,
        'meteredFeature',
        'account.additionalQuota',
      ),
      displayLabel: readNullableString(
        json,
        'displayLabel',
        'account.additionalQuota',
      ),
      routingPolicy: readNullableString(
        json,
        'routingPolicy',
        'account.additionalQuota',
      ),
    );
  }
}

class AccountSummary {
  const AccountSummary({
    required this.accountId,
    required this.email,
    required this.displayName,
    required this.planType,
    required this.routingPolicy,
    required this.status,
    required this.securityWorkAuthorized,
    required this.usage,
    required this.lastRefreshAt,
    required this.requestUsage,
    required this.isEmailDuplicate,
    required this.availableResetCredits,
    this.alias,
    this.chatgptAccountId,
    this.workspaceId,
    this.workspaceLabel,
    this.seatType,
    this.deactivationReason,
    this.resetAtPrimary,
    this.resetAtSecondary,
    this.resetAtMonthly,
    this.windowMinutesPrimary,
    this.windowMinutesSecondary,
    this.windowMinutesMonthly,
    this.capacityCreditsPrimary,
    this.remainingCreditsPrimary,
    this.capacityCreditsSecondary,
    this.remainingCreditsSecondary,
    this.capacityCreditsMonthly,
    this.remainingCreditsMonthly,
    this.creditsHas,
    this.creditsUnlimited,
    this.creditsBalance,
    this.auth,
    this.additionalQuotas = const <AccountAdditionalQuota>[],
    this.limitWarmupEnabled = false,
    this.resetCreditNearestExpiresAt,
    this.usageSampleAt,
  });

  final String accountId;
  final String? chatgptAccountId;
  final String email;
  final String? alias;
  final String displayName;
  final String? workspaceId;
  final String? workspaceLabel;
  final String? seatType;
  final String planType;
  final String routingPolicy;
  final String status;
  final bool securityWorkAuthorized;
  final AccountUsage? usage;
  final DateTime? lastRefreshAt;
  final DateTime? usageSampleAt;
  final AccountRequestUsage? requestUsage;
  final bool isEmailDuplicate;
  final int availableResetCredits;
  final String? deactivationReason;
  final DateTime? resetAtPrimary;
  final DateTime? resetAtSecondary;
  final DateTime? resetAtMonthly;
  final double? windowMinutesPrimary;
  final double? windowMinutesSecondary;
  final double? windowMinutesMonthly;
  final double? capacityCreditsPrimary;
  final double? remainingCreditsPrimary;
  final double? capacityCreditsSecondary;
  final double? remainingCreditsSecondary;
  final double? capacityCreditsMonthly;
  final double? remainingCreditsMonthly;
  final bool? creditsHas;
  final bool? creditsUnlimited;
  final double? creditsBalance;
  final AccountAuthStatus? auth;
  final List<AccountAdditionalQuota> additionalQuotas;
  final bool limitWarmupEnabled;
  final DateTime? resetCreditNearestExpiresAt;

  bool get isActive => status == 'active';
  bool get requiresAttention => status != 'active' || isEmailDuplicate;
  bool get isFreePlan => const <String>{
    'free',
    'guest',
    'go',
    'free_workspace',
    'quorum',
  }.contains(planType.trim().toLowerCase());
  bool get hasPaidSubscription => const <String>{
    'plus',
    'pro',
    'prolite',
    'team',
    'business',
    'enterprise',
    'edu',
  }.contains(planType.trim().toLowerCase());

  String get subscriptionLabel => switch (planType.trim().toLowerCase()) {
    'free' => 'ChatGPT Free',
    'plus' => 'ChatGPT Plus',
    'pro' => 'ChatGPT Pro',
    'prolite' => 'ChatGPT Pro Lite',
    'team' => 'ChatGPT Team',
    'business' => 'ChatGPT Business',
    'enterprise' => 'ChatGPT Enterprise',
    'edu' => 'ChatGPT Edu',
    'unknown' || '' => 'Subscription not reported',
    final value => 'ChatGPT ${_titleCasePlan(value)}',
  };

  String get workspaceSummary {
    final label = workspaceLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    if (workspaceId?.trim().isNotEmpty ?? false) {
      return 'Workspace identified';
    }
    return 'Not reported';
  }

  String get usageConnectionLabel {
    if (status == 'reauth_required') {
      return 'Reauthentication required';
    }
    if (status == 'deactivated') {
      return 'Disconnected';
    }
    if (status == 'paused') {
      return 'Paused';
    }
    final sample = usageSampleAt;
    if (sample == null) {
      return 'No upstream sample';
    }
    final age = DateTime.now().toUtc().difference(sample.toUtc());
    if (age > const Duration(minutes: 3)) {
      return 'Quota sample is stale';
    }
    return 'Quota API verified';
  }

  double? get visibleRemainingPercent {
    return usage?.monthlyRemainingPercent ??
        usage?.secondaryRemainingPercent ??
        usage?.primaryRemainingPercent;
  }

  factory AccountSummary.fromJson(Map<String, Object?> json) {
    final usageJson = readNullableObject(json, 'usage', 'account');
    final requestUsageJson = readNullableObject(
      json,
      'requestUsage',
      'account',
    );
    final authJson = readNullableObject(json, 'auth', 'account');
    final additionalQuotas = json['additionalQuotas'] == null
        ? const <AccountAdditionalQuota>[]
        : readList(json['additionalQuotas'], 'account.additionalQuotas')
              .map(
                (item) => AccountAdditionalQuota.fromJson(
                  readObject(item, 'account.additionalQuotas[]'),
                ),
              )
              .toList(growable: false);
    return AccountSummary(
      accountId: readString(json, 'accountId', 'account'),
      chatgptAccountId: readNullableString(json, 'chatgptAccountId', 'account'),
      email: readString(json, 'email', 'account'),
      alias: readNullableString(json, 'alias', 'account'),
      displayName: readString(json, 'displayName', 'account'),
      workspaceId: readNullableString(json, 'workspaceId', 'account'),
      workspaceLabel: readNullableString(json, 'workspaceLabel', 'account'),
      seatType: readNullableString(json, 'seatType', 'account'),
      planType: readString(json, 'planType', 'account'),
      routingPolicy:
          readNullableString(json, 'routingPolicy', 'account') ?? 'normal',
      status: readString(json, 'status', 'account'),
      securityWorkAuthorized: readBool(
        json,
        'securityWorkAuthorized',
        'account',
        fallback: false,
      ),
      usage: usageJson == null ? null : AccountUsage.fromJson(usageJson),
      lastRefreshAt: readNullableDateTime(json, 'lastRefreshAt', 'account'),
      usageSampleAt: readNullableDateTime(json, 'usageSampleAt', 'account'),
      requestUsage: requestUsageJson == null
          ? null
          : AccountRequestUsage.fromJson(requestUsageJson),
      isEmailDuplicate: readBool(
        json,
        'isEmailDuplicate',
        'account',
        fallback: false,
      ),
      availableResetCredits:
          readNullableNumber(
            json,
            'availableResetCredits',
            'account',
          )?.toInt() ??
          0,
      deactivationReason: readNullableString(
        json,
        'deactivationReason',
        'account',
      ),
      resetAtPrimary: readNullableDateTime(json, 'resetAtPrimary', 'account'),
      resetAtSecondary: readNullableDateTime(
        json,
        'resetAtSecondary',
        'account',
      ),
      resetAtMonthly: readNullableDateTime(json, 'resetAtMonthly', 'account'),
      windowMinutesPrimary: readNullableNumber(
        json,
        'windowMinutesPrimary',
        'account',
      )?.toDouble(),
      windowMinutesSecondary: readNullableNumber(
        json,
        'windowMinutesSecondary',
        'account',
      )?.toDouble(),
      windowMinutesMonthly: readNullableNumber(
        json,
        'windowMinutesMonthly',
        'account',
      )?.toDouble(),
      capacityCreditsPrimary: readNullableNumber(
        json,
        'capacityCreditsPrimary',
        'account',
      )?.toDouble(),
      remainingCreditsPrimary: readNullableNumber(
        json,
        'remainingCreditsPrimary',
        'account',
      )?.toDouble(),
      capacityCreditsSecondary: readNullableNumber(
        json,
        'capacityCreditsSecondary',
        'account',
      )?.toDouble(),
      remainingCreditsSecondary: readNullableNumber(
        json,
        'remainingCreditsSecondary',
        'account',
      )?.toDouble(),
      capacityCreditsMonthly: readNullableNumber(
        json,
        'capacityCreditsMonthly',
        'account',
      )?.toDouble(),
      remainingCreditsMonthly: readNullableNumber(
        json,
        'remainingCreditsMonthly',
        'account',
      )?.toDouble(),
      creditsHas: json['creditsHas'] == null
          ? null
          : readBool(json, 'creditsHas', 'account'),
      creditsUnlimited: json['creditsUnlimited'] == null
          ? null
          : readBool(json, 'creditsUnlimited', 'account'),
      creditsBalance: readNullableNumber(
        json,
        'creditsBalance',
        'account',
      )?.toDouble(),
      auth: authJson == null ? null : AccountAuthStatus.fromJson(authJson),
      additionalQuotas: additionalQuotas,
      limitWarmupEnabled: readBool(
        json,
        'limitWarmupEnabled',
        'account',
        fallback: false,
      ),
      resetCreditNearestExpiresAt: readNullableDateTime(
        json,
        'resetCreditNearestExpiresAt',
        'account',
      ),
    );
  }
}

String _titleCasePlan(String value) {
  return value
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String accountDisplayNameFromEmail(String email) {
  final localPart = email.trim().split('@').first;
  final normalized = localPart
      .replaceAll(RegExp(r'[._+\-\s]+'), ' ')
      .trim()
      .replaceFirst(RegExp(r'\d+$'), '')
      .trim();
  if (normalized.isEmpty) {
    return 'Account';
  }
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

enum AccountRemainingUsageOrder { highestFirst, lowestFirst }

List<AccountSummary> orderAccountsByRemainingUsage(
  Iterable<AccountSummary> accounts, {
  AccountRemainingUsageOrder order = AccountRemainingUsageOrder.highestFirst,
}) {
  final ordered = accounts.toList(growable: false);
  ordered.sort((left, right) {
    final leftRemaining = left.visibleRemainingPercent;
    final rightRemaining = right.visibleRemainingPercent;
    if (leftRemaining == null || rightRemaining == null) {
      if (leftRemaining == null && rightRemaining != null) {
        return 1;
      }
      if (leftRemaining != null && rightRemaining == null) {
        return -1;
      }
    }
    if (leftRemaining != null && rightRemaining != null) {
      final usageComparison = order == AccountRemainingUsageOrder.highestFirst
          ? rightRemaining.compareTo(leftRemaining)
          : leftRemaining.compareTo(rightRemaining);
      if (usageComparison != 0) {
        return usageComparison;
      }
    }
    final nameComparison = left.displayName.toLowerCase().compareTo(
      right.displayName.toLowerCase(),
    );
    return nameComparison != 0
        ? nameComparison
        : left.accountId.compareTo(right.accountId);
  });
  return ordered;
}
