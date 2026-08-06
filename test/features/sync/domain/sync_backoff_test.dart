import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_backoff.dart';

void main() {
  group('SyncBackoff', () {
    const SyncBackoff backoff = SyncBackoff(
      base: Duration(seconds: 5),
      max: Duration(minutes: 5),
    );

    test('doubles the delay each attempt', () {
      expect(backoff.delayFor(1), const Duration(seconds: 5));
      expect(backoff.delayFor(2), const Duration(seconds: 10));
      expect(backoff.delayFor(3), const Duration(seconds: 20));
      expect(backoff.delayFor(4), const Duration(seconds: 40));
    });

    test('caps at max', () {
      expect(backoff.delayFor(20), const Duration(minutes: 5));
    });

    test('attempt 0 or negative clamps to the base delay', () {
      expect(backoff.delayFor(0), const Duration(seconds: 5));
      expect(backoff.delayFor(-1), const Duration(seconds: 5));
    });
  });
}
