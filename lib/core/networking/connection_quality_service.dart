import 'dart:async';

import 'network_info.dart';

/// Coarse connectivity classification for the top-bar badge — [offline] when
/// [NetworkInfo.isConnected] is false, otherwise [weak]/[strong] based on how
/// long the connectivity check itself took to respond. This is not a real
/// signal-strength reading (the app has no access to WiFi/cellular signal
/// bars) — it's a latency proxy over the same reachability ping
/// `NetworkInfo` already performs, good enough to warn "you're online but
/// it's slow" without adding a new permission or package.
enum ConnectionQuality { offline, weak, strong }

/// Periodically samples [NetworkInfo.isConnected] (timing the call for the
/// weak/strong classification) and reacts immediately to
/// [NetworkInfo.onStatusChange] for fast offline/back-online detection
/// in between polls — the two-source approach mirrors why
/// `HoldingsRepository._isOnline` already treats a proactive check as more
/// trustworthy than waiting for a write to fail.
class ConnectionQualityService {
  ConnectionQualityService(
    this._networkInfo, {
    this.pollInterval = const Duration(seconds: 15),
    this.weakThreshold = const Duration(milliseconds: 1500),
  });

  final NetworkInfo _networkInfo;
  final Duration pollInterval;

  /// A connectivity check that takes longer than this to resolve
  /// "connected" is classified [ConnectionQuality.weak] instead of
  /// [ConnectionQuality.strong] — a heuristic, not a measured bandwidth/
  /// signal value.
  final Duration weakThreshold;

  final StreamController<ConnectionQuality> _controller =
      StreamController<ConnectionQuality>.broadcast();
  StreamSubscription<Object?>? _statusSubscription;
  Timer? _pollTimer;
  ConnectionQuality _current = ConnectionQuality.strong;

  Stream<ConnectionQuality> get onQualityChanged => _controller.stream;

  ConnectionQuality get current => _current;

  /// Starts polling immediately and subscribing to status-change events —
  /// call once at app start (mirrors `SyncRunner`/other singleton services'
  /// own explicit start step, no work happens just from construction/DI
  /// resolution).
  void start() {
    unawaited(_check());
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (final _) => unawaited(_check()));
    _statusSubscription?.cancel();
    _statusSubscription = _networkInfo.onStatusChange.listen((final _) => unawaited(_check()));
  }

  /// Runs one classification pass immediately, outside the poll schedule —
  /// exposed for tests (avoids needing a running `Timer.periodic`, which
  /// `tester.pumpAndSettle()` would wait on forever) and as a manual-refresh
  /// hook if a future UI wants a "check now" action.
  Future<void> checkNow() => _check();

  Future<void> _check() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final bool connected = await _networkInfo.isConnected;
    stopwatch.stop();

    final ConnectionQuality next = !connected
        ? ConnectionQuality.offline
        : stopwatch.elapsed > weakThreshold
            ? ConnectionQuality.weak
            : ConnectionQuality.strong;

    if (next == _current) return;
    _current = next;
    _controller.add(next);
  }

  void dispose() {
    _pollTimer?.cancel();
    unawaited(_statusSubscription?.cancel());
    unawaited(_controller.close());
  }
}
