import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../config/app_config.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<InternetConnectionStatus> get onStatusChange;
}

class NetworkInfoImpl implements NetworkInfo {
  final InternetConnectionChecker connectionChecker;

  NetworkInfoImpl(this.connectionChecker);

  @override
  Future<bool> get isConnected async {
    if (AppConfig.isDevelopment) return true; // TODO: remove before release
    return connectionChecker.hasConnection;
  }

  @override
  Stream<InternetConnectionStatus> get onStatusChange => connectionChecker.onStatusChange;
}
