import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../../features/app_control/data/local/app_control_local_store.dart';
import '../../../features/app_control/data/remote/app_control_remote_data_source.dart';
import '../../../features/app_control/data/repo/app_control_repository.dart';
import '../../../features/app_control/data/repo/app_control_repository_impl.dart';
import '../../../features/app_control/logic/cubit/app_control_cubit.dart';
import '../../storage/key_value_store.dart';

void registerAppControlModule(final GetIt getIt) {
  getIt.registerLazySingleton<AppControlRemoteDataSource>(() => AppControlRemoteDataSource(getIt<http.Client>()));
  getIt.registerLazySingleton<AppControlLocalStore>(() => AppControlLocalStore(getIt<KeyValueStore>()));
  getIt.registerLazySingleton<AppControlRepository>(() => AppControlRepositoryImpl(remote: getIt(), local: getIt()));
  getIt.registerLazySingleton<AppControlCubit>(() => AppControlCubit(getIt<AppControlRepository>()));
}
