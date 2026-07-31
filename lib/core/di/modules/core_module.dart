import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../networking/network_info.dart';
import '../../service/secure_storage.dart';
import '../../service/voice_search_service.dart';
import '../../storage/key_value_store.dart';

/// App-wide singletons that every feature module may depend on: network
/// status, secure/plain key-value storage, and cross-cutting services.
Future<void> registerCoreModule(final GetIt getIt) async {
  getIt.registerLazySingleton(InternetConnectionChecker.createInstance);

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
