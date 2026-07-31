/// Exponential backoff schedule for retrying a failed sync operation:
/// 30s, 1m, 2m, 4m, 8m — capped, so a long-parked operation isn't retried
/// (and doesn't spam the server) more than once every 8 minutes.
class SyncBackoff {
  const SyncBackoff._();

  static const Duration _base = Duration(seconds: 30);
  static const Duration _cap = Duration(minutes: 8);

  static Duration forAttempt(final int attempts) {
    if (attempts <= 0) return Duration.zero;
    final int factor = 1 << (attempts - 1); // 1, 2, 4, 8, 16...
    final Duration delay = _base * factor;
    return delay > _cap ? _cap : delay;
  }

  static bool isEligible(
    final int attempts,
    final DateTime? lastAttemptAt,
    final DateTime now,
  ) {
    if (lastAttemptAt == null) return true;
    return now.difference(lastAttemptAt) >= forAttempt(attempts);
  }
}
