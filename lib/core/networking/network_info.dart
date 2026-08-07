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
  final InternetConnectionChecker connectionChecker;

  NetworkInfoImpl(this.connectionChecker);

  @override
  Future<bool> get isConnected => connectionChecker.hasConnection;

  @override
  Stream<InternetConnectionStatus> get onStatusChange => connectionChecker.onStatusChange;
}
