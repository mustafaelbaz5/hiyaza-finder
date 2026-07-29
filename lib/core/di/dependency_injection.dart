import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../features/holdings/data/repository/holdings_repository.dart';
import '../networking/network_info.dart';
import '../service/secure_storage.dart';
import '../service/voice_search_service.dart';

final getIt = GetIt.instance;

Future<void> setUpDependencies() async {
  // --- External ---
  getIt.registerLazySingleton(() => InternetConnectionChecker.createInstance());
  final FlutterSecureStorage flutterSecureStorage =
      const FlutterSecureStorage();

  if (!getIt.isRegistered<SecureStorage>()) {
    getIt.registerLazySingleton<SecureStorage>(
      () => SecureStorage(flutterSecureStorage),
    );
  }

  // --- Core ---
  getIt.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(getIt()));

  // // --- Dio ---
  // getIt.registerLazySingleton<Dio>(
  //   () => DioFactory.create(
  //     baseUrl: AppConfig.baseUrl,
  //     getToken: () =>
  //         getIt<SecureStorage>().read(key: AppConstants.userDataKey),
  //     enableLogging: AppConfig.enableLogging,
  //   ),
  // );

  // --- Repositories ---
  // getIt.registerLazySingleton(() => AuthRepository(getIt()));
  getIt.registerLazySingleton<HoldingsRepository>(() => HoldingsRepository());

  // --- Services ---
  getIt.registerLazySingleton<VoiceSearchService>(() => VoiceSearchService());

  // --- Use Cases ---
  // getIt.registerFactory(() => LoginUseCase(getIt()));
}
