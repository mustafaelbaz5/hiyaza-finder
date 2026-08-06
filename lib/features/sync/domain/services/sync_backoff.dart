/// Exponential backoff schedule for [SyncRunner] retries — pure function of
/// attempt count, no I/O, easily unit-tested in isolation.
class SyncBackoff {
  const SyncBackoff({
    this.base = const Duration(seconds: 5),
    this.max = const Duration(minutes: 5),
  });

  final Duration base;
  final Duration max;

  /// Delay before retry number [attempt] (1-indexed: the delay before the
  /// *first* retry, i.e. after 1 failed attempt, is `base`). Doubles each
  /// attempt, capped at [max] so a long-failing operation doesn't end up
  /// waiting hours between tries.
  Duration delayFor(final int attempt) {
    final int shift = (attempt - 1).clamp(0, 10);
    final int millis = base.inMilliseconds * (1 << shift);
    final Duration delay = Duration(milliseconds: millis);
    return delay > max ? max : delay;
  }
}
