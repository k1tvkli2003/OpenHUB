import 'package:openhub_windows/src/state/async_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refresh failure keeps the last successful value and freshness', () {
    final fetchedAt = DateTime.utc(2026, 8, 9, 7);
    final sampleAt = DateTime.utc(2026, 8, 9, 6, 55);
    final ready = AsyncSection<int>(
      phase: SectionPhase.ready,
      value: 15,
      lastSuccessfulFetch: fetchedAt,
      sourceSampleAt: sampleAt,
    );

    final refreshing = ready.begin();
    final failed = refreshing.fail(StateError('request logs unavailable'));

    expect(refreshing.phase, SectionPhase.refreshing);
    expect(failed.value, 15);
    expect(failed.lastSuccessfulFetch, fetchedAt);
    expect(failed.sourceSampleAt, sampleAt);
    expect(failed.isStale, isTrue);
  });
}
