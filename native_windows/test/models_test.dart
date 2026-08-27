import 'package:openhub_windows/src/core/api/api_exception.dart';
import 'package:openhub_windows/src/models/account_summary.dart';
import 'package:openhub_windows/src/models/advanced_settings.dart';
import 'package:openhub_windows/src/models/api_key_info.dart';
import 'package:openhub_windows/src/models/automation_data.dart';
import 'package:openhub_windows/src/models/dashboard_overview.dart';
import 'package:openhub_windows/src/models/dashboard_settings.dart';
import 'package:openhub_windows/src/models/reports_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const accountJson = <String, Object?>{
    'accountId': 'account-1',
    'email': 'local@example.test',
    'alias': 'Primary',
    'displayName': 'Primary account',
    'workspaceLabel': null,
    'seatType': null,
    'planType': 'pro',
    'routingPolicy': 'normal',
    'status': 'active',
    'securityWorkAuthorized': false,
    'usage': <String, Object?>{
      'primaryRemainingPercent': 72.5,
      'secondaryRemainingPercent': 61.0,
      'monthlyRemainingPercent': null,
    },
    'lastRefreshAt': '2026-08-09T07:00:00Z',
    'usageSampleAt': '2026-08-09T07:01:00Z',
    'requestUsage': <String, Object?>{
      'requestCount': 4,
      'totalTokens': 1200,
      'cachedInputTokens': 300,
      'totalCostUsd': 0.42,
    },
    'isEmailDuplicate': false,
    'availableResetCredits': 2,
    'deactivationReason': null,
  };

  test('parses the account summary without credential fields', () {
    final account = AccountSummary.fromJson(accountJson);

    expect(account.accountId, 'account-1');
    expect(account.isActive, isTrue);
    expect(account.visibleRemainingPercent, 61.0);
    expect(account.requestUsage?.totalTokens, 1200);
    expect(account.availableResetCredits, 2);
    expect(account.usageSampleAt, DateTime.utc(2026, 8, 9, 7, 1));
  });

  test('derives compact account display names from email', () {
    expect(accountDisplayNameFromEmail('m18247860@gmail.com'), 'M');
    expect(accountDisplayNameFromEmail('keyvan23@example.com'), 'Keyvan');
    expect(
      accountDisplayNameFromEmail('ali.reza_2024@example.com'),
      'Ali reza',
    );
    expect(accountDisplayNameFromEmail('12345@example.com'), 'Account');
  });

  test('monthly-only quota is the visible account quota', () {
    final account = AccountSummary.fromJson(<String, Object?>{
      ...accountJson,
      'usage': <String, Object?>{
        'primaryRemainingPercent': null,
        'secondaryRemainingPercent': null,
        'monthlyRemainingPercent': 88.0,
      },
    });

    expect(account.visibleRemainingPercent, 88.0);
  });

  test('classifies only reported subscription tiers as paid', () {
    final paid = AccountSummary.fromJson(<String, Object?>{
      ...accountJson,
      'planType': 'plus',
    });
    final free = AccountSummary.fromJson(<String, Object?>{
      ...accountJson,
      'planType': 'free',
    });
    final unknown = AccountSummary.fromJson(<String, Object?>{
      ...accountJson,
      'planType': 'unknown',
    });

    expect(paid.hasPaidSubscription, isTrue);
    expect(free.hasPaidSubscription, isFalse);
    expect(free.isFreePlan, isTrue);
    expect(unknown.hasPaidSubscription, isFalse);
  });

  test('parses dashboard freshness separately from fetch time', () {
    final overview = DashboardOverview.fromJson(<String, Object?>{
      'lastSyncAt': '2026-08-09T07:01:00Z',
      'timeframe': <String, Object?>{
        'key': '7d',
        'windowMinutes': 10080,
        'bucketSeconds': 3600,
        'bucketCount': 168,
      },
      'accounts': <Object?>[accountJson],
      'summary': <String, Object?>{
        'primaryWindow': <String, Object?>{
          'remainingPercent': 72.5,
          'capacityCredits': 100.0,
          'remainingCredits': 72.5,
          'resetAt': '2026-08-09T12:00:00Z',
          'windowMinutes': 300,
        },
        'secondaryWindow': null,
        'cost': <String, Object?>{'currency': 'USD', 'totalUsd': 1.25},
        'metrics': <String, Object?>{
          'requests': 5,
          'tokens': 1400,
          'conversations': 2,
          'errorRate': 0.0,
          'errorCount': 0,
          'topError': null,
        },
      },
      'windows': <String, Object?>{},
      'trends': <String, Object?>{},
    });

    expect(overview.lastSyncAt, DateTime.utc(2026, 8, 9, 7, 1));
    expect(overview.activeAccounts, 1);
    expect(overview.primaryWindow.remainingPercent, 72.5);
    expect(overview.totalUsd, 1.25);
  });

  test('fails closed when a required API field changes type', () {
    expect(
      () => AccountSummary.fromJson(<String, Object?>{
        ...accountJson,
        'accountId': 42,
      }),
      throwsA(isA<ApiSchemaException>()),
    );
  });

  test('parses reports and preserves latency fields', () {
    final reports = ReportsData.fromJson(<String, Object?>{
      'summary': <String, Object?>{
        'totalCostUsd': 1.5,
        'totalInputTokens': 100,
        'totalOutputTokens': 40,
        'totalCachedTokens': 20,
        'totalRequests': 3,
        'totalErrors': 1,
        'activeAccounts': 2,
        'totalConversations': 2,
        'avgCostPerDay': 0.75,
        'avgRequestsPerDay': 1.5,
      },
      'comparison': <String, Object?>{
        'canCompare': true,
        'previous': <String, Object?>{
          'totalCostUsd': 1.0,
          'totalTokens': 90,
          'totalRequests': 2,
        },
      },
      'daily': <Object?>[
        <String, Object?>{
          'date': '2026-08-09',
          'requests': 3,
          'inputTokens': 100,
          'outputTokens': 40,
          'cachedInputTokens': 20,
          'costUsd': 1.5,
          'activeAccounts': 2,
          'conversations': 2,
          'errorCount': 1,
          'medianTtftMs': 120.0,
          'medianTps': 25.0,
          'medianQueueMs': 8.0,
        },
      ],
      'byModel': <Object?>[],
      'byAccount': <Object?>[],
      'byUseragent': <Object?>[],
    });

    expect(reports.summary.totalTokens, 140);
    expect(reports.daily.single.medianQueueMs, 8.0);
  });

  test(
    'parses one-time API key result without weakening stored-key schema',
    () {
      final result = ApiKeyCreateResult.fromJson(<String, Object?>{
        'id': 'key-1',
        'name': 'Native client',
        'keyPrefix': 'lb_test…',
        'key': 'fixture-secret',
        'allowedModels': null,
        'applyToCodexModel': false,
        'enforcedModel': null,
        'enforcedReasoningEffort': null,
        'enforcedServiceTier': null,
        'trafficClass': 'foreground',
        'transportPolicyOverride': null,
        'usageSections': 'upstream_limits,account_pool_usage',
        'expiresAt': null,
        'isActive': true,
        'accountAssignmentScopeEnabled': false,
        'sourceAssignmentScopeEnabled': false,
        'assignedAccountIds': <Object?>[],
        'assignedSourceIds': <Object?>[],
        'createdAt': '2026-08-09T07:00:00Z',
        'lastUsedAt': null,
        'limits': <Object?>[],
        'usageSummary': null,
        'pooledRemainingPercentPrimary': null,
        'pooledRemainingPercentSecondary': null,
        'pooledCapacityCreditsPrimary': 0.0,
      });

      expect(result.info.keyPrefix, 'lb_test…');
      expect(result.secret, 'fixture-secret');
    },
  );

  test('parses automation pages and schedule scope', () {
    final page = AutomationJobsPage.fromJson(<String, Object?>{
      'items': <Object?>[
        <String, Object?>{
          'id': 'job-1',
          'name': 'Morning warm-up',
          'enabled': true,
          'includePausedAccounts': false,
          'accountScopeAll': true,
          'schedule': <String, Object?>{
            'type': 'daily',
            'time': '09:00',
            'timezone': 'Asia/Tehran',
            'thresholdMinutes': 0,
            'days': <Object?>['sat', 'sun'],
          },
          'model': 'gpt-test',
          'reasoningEffort': 'low',
          'prompt': 'Warm up.',
          'accountIds': <Object?>[],
          'nextRunAt': null,
          'lastRun': null,
        },
      ],
      'total': 1,
      'hasMore': false,
    });

    expect(page.items.single.schedule.days, <String>['sat', 'sun']);
    expect(page.items.single.accountScopeAll, isTrue);
  });

  test('settings schema validates the pinned typed contract', () {
    final settings = DashboardSettings.fromJson(_settingsJson());

    expect(settings.routingStrategy, 'usage_weighted');
    expect(settings.version, 3);
    expect(settings.boolValue('apiKeyAuthEnabled'), isTrue);
  });

  test('advanced settings contracts parse bounded backend responses', () {
    final sources = ModelSourcesCatalog.fromJson(<String, Object?>{
      'sources': <Object?>[
        <String, Object?>{
          'id': 'source-1',
          'name': 'Local compatible source',
          'kind': 'openai_compatible',
          'baseUrl': 'http://127.0.0.1:9000/v1',
          'isEnabled': true,
          'healthStatus': 'healthy',
          'supportsChatCompletions': true,
          'supportsResponses': true,
          'supportsAudioTranscriptions': false,
          'timeoutSeconds': 20,
          'maxConcurrency': 4,
          'createdAt': '2026-08-09T07:00:00Z',
          'updatedAt': '2026-08-09T07:00:00Z',
          'models': <Object?>[
            <String, Object?>{
              'id': 1,
              'sourceId': 'source-1',
              'model': 'fixture-model',
              'displayName': 'Fixture model',
              'contextWindow': 128000,
              'maxOutputTokens': 4096,
              'supportsStreaming': true,
              'supportsTools': true,
              'supportsVision': false,
              'inputPer1M': null,
              'cachedInputPer1M': null,
              'outputPer1M': null,
              'audioPerMinute': null,
              'rawMetadataJson': null,
              'isEnabled': true,
              'createdAt': '2026-08-09T07:00:00Z',
              'updatedAt': '2026-08-09T07:00:00Z',
            },
          ],
        },
      ],
    });
    final firewall = FirewallPolicy.fromJson(<String, Object?>{
      'mode': 'allowlist_active',
      'entries': <Object?>[
        <String, Object?>{
          'ipAddress': '127.0.0.1',
          'createdAt': '2026-08-09T07:00:00Z',
        },
      ],
    });
    final planner = QuotaPlannerSettings.fromJson(<String, Object?>{
      'mode': 'shadow',
      'timezone': 'Asia/Tehran',
      'workingDays': <Object?>[0, 1, 2, 3, 4],
      'workingHoursStart': '09:00',
      'workingHoursEnd': '18:00',
      'prewarmEnabled': true,
      'prewarmLeadMinutes': 300,
      'maxWarmupsPerDay': 3,
      'maxWarmupCreditsPerDay': 0.0,
      'minExpectedGain': 1.0,
      'forecastQuantile': 'p75',
      'allowSyntheticTraffic': false,
      'warmupModelPreference': null,
      'dryRun': true,
    });
    final forecast = QuotaPlannerForecast.fromJson(<String, Object?>{
      'generatedAt': '2026-08-09T07:00:00Z',
      'horizonHours': 36,
      'slotSeconds': 900,
      'totalDemandUnits': 4.5,
      'peakSlotStart': '2026-08-09T09:00:00Z',
      'peakDemandUnits': 1.2,
      'simulation': <String, Object?>{
        'loss': 0.2,
        'unmetDemand': 0.1,
        'wastedCapacity': 0.1,
        'coldStartPenalty': 0.0,
        'synchronizationPenalty': 0.0,
        'forecastUnits': 4.5,
        'servedUnits': 4.4,
      },
      'slots': <Object?>[
        <String, Object?>{
          'slotStart': '2026-08-09T07:00:00Z',
          'demandUnits': 0.5,
          'requestCount': 1.0,
          'source': 'history',
        },
      ],
    });
    final sticky = StickySessionsPage.fromJson(<String, Object?>{
      'entries': <Object?>[
        <String, Object?>{
          'key': 'fixture-session',
          'displayName': 'Fixture session',
          'kind': 'codex_session',
          'createdAt': '2026-08-09T07:00:00Z',
          'updatedAt': '2026-08-09T08:00:00Z',
          'expiresAt': null,
          'isStale': false,
        },
      ],
      'stalePromptCacheCount': 0,
      'total': 1,
      'hasMore': false,
    });

    expect(sources.sources.single.models.single.supportsTools, isTrue);
    expect(firewall.entries.single.ipAddress, '127.0.0.1');
    expect(planner.workingDays, <int>[0, 1, 2, 3, 4]);
    expect(forecast.simulation.servedUnits, 4.4);
    expect(sticky.entries.single.kind, 'codex_session');
  });

  test('advanced model-source integer fields fail closed', () {
    expect(
      () => ModelSource.fromJson(<String, Object?>{
        'id': 'source-1',
        'name': 'Bad source',
        'kind': 'openai_compatible',
        'baseUrl': 'http://127.0.0.1:9000/v1',
        'isEnabled': true,
        'healthStatus': 'unknown',
        'supportsChatCompletions': true,
        'supportsResponses': true,
        'supportsAudioTranscriptions': false,
        'timeoutSeconds': 1.5,
        'maxConcurrency': null,
        'createdAt': '2026-08-09T07:00:00Z',
        'updatedAt': '2026-08-09T07:00:00Z',
        'models': <Object?>[],
      }),
      throwsA(isA<ApiSchemaException>()),
    );
  });
}

Map<String, Object?> _settingsJson() => <String, Object?>{
  'stickyThreadsEnabled': true,
  'upstreamStreamTransport': 'auto',
  'prohibitFastMode': false,
  'httpDownstreamTransportPolicy': 'smart',
  'proxyAccountResponseCreateLimit': 0,
  'proxyAccountStreamLimit': 0,
  'proxyAccountStreamRecoveryReserve': 0,
  'upstreamProxyRoutingEnabled': false,
  'upstreamProxyDefaultPoolId': null,
  'preferEarlierResetAccounts': true,
  'preferEarlierResetWindow': 'primary',
  'showResetCreditBadges': true,
  'autoRedeemResetCreditsBeforeExpiry': false,
  'showResetCreditExpiryBadge': true,
  'routingStrategy': 'usage_weighted',
  'relativeAvailabilityPower': 1.0,
  'relativeAvailabilityTopK': 3,
  'singleAccountId': null,
  'openaiCacheAffinityMaxAgeSeconds': 3600,
  'dashboardSessionTtlSeconds': 3600,
  'httpResponsesSessionBridgePromptCacheIdleTtlSeconds': 300,
  'httpResponsesSessionBridgeGatewaySafeMode': true,
  'stickyReallocationBudgetThresholdPct': 10.0,
  'stickyReallocationPrimaryBudgetThresholdPct': 10.0,
  'stickyReallocationSecondaryBudgetThresholdPct': 10.0,
  'warmupModel': 'gpt-test',
  'importWithoutOverwrite': true,
  'totpRequiredOnLogin': false,
  'totpConfigured': false,
  'apiKeyAuthEnabled': true,
  'hideUpstreamQuotaFromApiKeys': false,
  'limitWarmupEnabled': false,
  'limitWarmupWindows': 'both',
  'limitWarmupModel': 'gpt-test',
  'limitWarmupPrompt': 'Warm up.',
  'limitWarmupCooldownSeconds': 60,
  'limitWarmupExhaustedThresholdPercent': 5.0,
  'limitWarmupIdleThresholdPercent': 80.0,
  'limitWarmupMinAvailablePercent': 10.0,
  'weeklyPaceWorkingDays': '0,1,2,3,4,5,6',
  'weeklyPaceSmoothingMinutes': 30,
  'limitWarmupStaggeredIdleEnabled': true,
  'requestLogRetentionDays': 30,
  'usageHistoryRetentionDays': 45,
  'requestLogRetentionOverrideDays': null,
  'usageHistoryRetentionOverrideDays': null,
  'additionalQuotaRoutingPolicies': <String, Object?>{},
  'additionalQuotaPolicies': <Object?>[],
  'guestAccessEnabled': false,
  'guestPasswordConfigured': false,
  'version': 3,
};
