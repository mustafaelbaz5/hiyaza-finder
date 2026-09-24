import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../../features/cities/data/local/city_snapshot_cache.dart';
import '../../../features/cities/data/local/city_catalog_store.dart';
import '../../../features/cities/data/remote/city_remote_ds.dart';
import '../../../features/cities/data/repo/city_repo.dart';
import '../../../features/cities/data/repo/city_repo_impl.dart';
import '../../../features/cities/logic/cubit/city_picker_cubit.dart';
import '../../../features/holdings/data/repo/holdings_repository.dart';
import '../../storage/key_value_store.dart';

void registerCitiesModule(final GetIt getIt) {
  getIt.registerLazySingleton<CityRemoteDataSource>(
    () => CityRemoteDataSource(getIt<http.Client>()),
  );
  getIt.registerLazySingleton<CitySnapshotCache>(CitySnapshotCache.new);
  getIt.registerLazySingleton<CityCatalogStore>(CityCatalogStore.new);

  getIt.registerLazySingleton<CityRepo>(
    () => CityRepoImpl(
      dataSource: getIt<CityRemoteDataSource>(),
      cache: getIt<CitySnapshotCache>(),
      keyValueStore: getIt<KeyValueStore>(),
      catalogStore: getIt<CityCatalogStore>(),
    ),
  );

  getIt.registerLazySingleton<CityPickerCubit>(
    () => CityPickerCubit(getIt<CityRepo>(), getIt<HoldingsRepository>()),
  );
}
