import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_backoff.dart';

void main() {
  test('an operation with no prior attempt is always eligible', () {
    expect(SyncBackoff.isEligible(0, null, DateTime.now()), isTrue);
  });

  test('forAttempt doubles each time, starting at 30s', () {
    expect(SyncBackoff.forAttempt(1), const Duration(seconds: 30));
    expect(SyncBackoff.forAttempt(2), const Duration(minutes: 1));
    expect(SyncBackoff.forAttempt(3), const Duration(minutes: 2));
    expect(SyncBackoff.forAttempt(4), const Duration(minutes: 4));
  });

  test('forAttempt is capped at 8 minutes', () {
    expect(SyncBackoff.forAttempt(10), const Duration(minutes: 8));
  });

  test('not eligible before the backoff window has elapsed', () {
    final DateTime now = DateTime(2026, 1, 1, 12, 0, 0);
    final DateTime lastAttempt = now.subtract(const Duration(seconds: 10));
    expect(SyncBackoff.isEligible(1, lastAttempt, now), isFalse);
  });

  test('eligible once the backoff window has elapsed', () {
    final DateTime now = DateTime(2026, 1, 1, 12, 0, 0);
    final DateTime lastAttempt = now.subtract(const Duration(seconds: 31));
    expect(SyncBackoff.isEligible(1, lastAttempt, now), isTrue);
  });
}
