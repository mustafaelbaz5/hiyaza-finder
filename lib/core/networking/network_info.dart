import 'package:internet_connection_checker/internet_connection_checker.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<InternetConnectionStatus> get onStatusChange;
}

/// Same check in both flavors — no dev/production split. [connectionChecker]
/// is configured (see `core_module.dart`) to check the app's own Supabase
/// backend plus a couple of well-known fallback hosts, rather than an
/// arbitrary public endpoint unrelated to what the app actually needs to
/// reach.
class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this.connectionChecker);

  final InternetConnectionChecker connectionChecker;

  /// `InternetConnectionChecker.hasConnection` is a single attempt per host
  /// with its own fixed per-address timeout (5s by default) and no retry —
  /// a single slow DNS lookup or transient timeout (common right after app
  /// launch, before the OS network stack/DNS cache has warmed up) reports
  /// "offline" even on a genuinely working connection. This previously
  /// showed the startup "no internet" dialog to a field worker who really
  /// was online, with the dialog's own retry button hitting the exact same
  /// single-shot fragility. One retry after a short delay is enough to
  /// absorb that class of transient failure without meaningfully slowing
  /// down the real offline case (which fails both attempts either way).
  static const Duration _retryDelay = Duration(milliseconds: 800);

  @override
  Future<bool> get isConnected async {
    if (await connectionChecker.hasConnection) return true;
    await Future<void>.delayed(_retryDelay);
    return connectionChecker.hasConnection;
  }

  @override
  Stream<InternetConnectionStatus> get onStatusChange => connectionChecker.onStatusChange;
}
