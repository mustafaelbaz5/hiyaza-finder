import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/cities/data/city_repository_impl.dart';
import '../../../features/cities/data/city_snapshot_cache.dart';
import '../../../features/cities/data/supabase_city_data_source.dart';
import '../../../features/cities/domain/repositories/city_repository.dart';
import '../../../features/cities/presentation/cubit/city_picker_cubit.dart';
import '../../../features/holdings/data/repository/holdings_repository.dart';
import '../../storage/key_value_store.dart';

void registerCitiesModule(final GetIt getIt) {
  getIt.registerLazySingleton<SupabaseCityDataSource>(
    () => SupabaseCityDataSource(Supabase.instance.client),
  );
  getIt.registerLazySingleton<CitySnapshotCache>(CitySnapshotCache.new);

  getIt.registerLazySingleton<CityRepository>(
    () => CityRepositoryImpl(
      dataSource: getIt<SupabaseCityDataSource>(),
      cache: getIt<CitySnapshotCache>(),
      keyValueStore: getIt<KeyValueStore>(),
    ),
  );

  // Factory, not a singleton — a fresh cubit (fresh loading state) each
  // time the city picker screen opens.
  getIt.registerFactory<CityPickerCubit>(
    () => CityPickerCubit(getIt<CityRepository>(), getIt<HoldingsRepository>()),
  );
}
