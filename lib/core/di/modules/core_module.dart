import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../config/app_config.dart';
import '../../networking/network_info.dart';
import '../../service/secure_storage.dart';
import '../../service/voice_search_service.dart';
import '../../storage/key_value_store.dart';

/// Hosts [NetworkInfo] checks for reachability — the app's own Supabase
/// backend first (what actually matters: "can this app do its job?"), plus
/// two well-known, virtually-always-up public hosts as fallbacks so a
/// momentary Supabase-side blip alone doesn't read as "no internet" when
/// the device is otherwise online. Any one responding is enough
/// (`requireAllAddressesToRespond` defaults to false).
List<AddressCheckOption> _connectivityCheckAddresses() {
  final List<AddressCheckOption> options = <AddressCheckOption>[];
  final String supabaseUrl = AppConfig.supabaseUrl;
  if (supabaseUrl.isNotEmpty) {
    options.add(AddressCheckOption(uri: Uri.parse(supabaseUrl)));
  }
  options.addAll(<AddressCheckOption>[
    AddressCheckOption(uri: Uri.parse('https://one.one.one.one')),
    AddressCheckOption(uri: Uri.parse('https://dns.google')),
  ]);
  return options;
}

/// App-wide singletons that every feature module may depend on: network
/// status, secure/plain key-value storage, and cross-cutting services.
Future<void> registerCoreModule(final GetIt getIt) async {
  getIt.registerLazySingleton(
    () => InternetConnectionChecker.createInstance(
      addresses: _connectivityCheckAddresses(),
    ),
  );

  if (!getIt.isRegistered<SecureStorage>()) {
    getIt.registerLazySingleton<SecureStorage>(
      () => const SecureStorage(FlutterSecureStorage()),
    );
  }

  getIt.registerLazySingleton<KeyValueStore>(
    () => const SharedPreferencesKeyValueStore(),
  );

  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(getIt()));

  getIt.registerLazySingleton<VoiceSearchService>(VoiceSearchService.new);
}
