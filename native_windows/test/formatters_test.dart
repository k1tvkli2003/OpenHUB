import 'package:openhub_windows/src/ui/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 9, 12);

  test('relative timestamps distinguish past and future values', () {
    expect(
      formatRelative(now.subtract(const Duration(seconds: 2)), now: now),
      'just now',
    );
    expect(
      formatRelative(now.subtract(const Duration(minutes: 7)), now: now),
      '7m ago',
    );
    expect(
      formatRelative(now.add(const Duration(seconds: 20)), now: now),
      'in 20s',
    );
    expect(
      formatRelative(now.add(const Duration(hours: 3)), now: now),
      'in 3h',
    );
    expect(formatRelative(now.add(const Duration(days: 2)), now: now), 'in 2d');
  });

  test('relative timestamp null contract remains stable', () {
    expect(formatRelative(null, now: now), 'never');
  });

  test('reset countdown keeps useful minute and hour precision', () {
    expect(
      formatResetCountdown(
        now.add(const Duration(hours: 2, minutes: 14)),
        now: now,
      ),
      '02h 14m',
    );
    expect(
      formatResetCountdown(
        now.add(const Duration(days: 3, hours: 8, minutes: 42)),
        now: now,
      ),
      '3d 08h',
    );
  });

  test('reset countdown names missing, imminent, and elapsed resets', () {
    expect(formatResetCountdown(null, now: now), 'Not reported');
    expect(
      formatResetCountdown(now.add(const Duration(seconds: 20)), now: now),
      '20s',
    );
    expect(
      formatResetCountdown(now.subtract(const Duration(seconds: 1)), now: now),
      'Due now',
    );
  });
}
