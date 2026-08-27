import 'package:openhub_windows/src/core/api/api_exception.dart';
import 'package:openhub_windows/src/models/api_key_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API-key analytics decode trends and account attribution', () {
    final trends = ApiKeyTrends.fromJson(<String, Object?>{
      'keyId': 'key-1',
      'cost': <Object?>[
        <String, Object?>{'t': '2026-08-08T12:00:00Z', 'v': 1.25},
      ],
      'tokens': <Object?>[
        <String, Object?>{'t': '2026-08-08T12:00:00Z', 'v': 4200},
      ],
    });
    final usage = ApiKeyUsage7Day.fromJson(<String, Object?>{
      'keyId': 'key-1',
      'totalTokens': 4200,
      'totalCostUsd': 1.25,
      'totalRequests': 4,
      'cachedInputTokens': 1000,
      'accountCosts': <Object?>[
        <String, Object?>{
          'accountId': 'account-1',
          'email': 'masked@example.test',
          'costUsd': 1.25,
          'isDeleted': false,
        },
      ],
    });
    final analytics = ApiKeyAnalytics(trends: trends, usage7Day: usage);

    expect(analytics.latestSampleAt, DateTime.utc(2026, 8, 8, 12));
    expect(analytics.usage7Day.accountCosts.single.accountId, 'account-1');
    expect(analytics.trends.tokens.single.value, 4200);
  });

  test('API-key trend rejects a missing timestamp', () {
    expect(
      () => ApiKeyTrends.fromJson(<String, Object?>{
        'keyId': 'key-1',
        'cost': <Object?>[
          <String, Object?>{'t': null, 'v': 1},
        ],
        'tokens': <Object?>[],
      }),
      throwsA(isA<ApiSchemaException>()),
    );
  });
}
