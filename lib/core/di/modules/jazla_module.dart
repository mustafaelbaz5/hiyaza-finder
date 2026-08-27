import 'package:get_it/get_it.dart';

import '../../../features/jazla/data/local/jazla_export_service.dart';
import '../../../features/jazla/data/local/jazla_search_service.dart';
import '../../../features/jazla/data/local/jazla_store.dart';
import '../../../features/jazla/data/repo/jazla_repo.dart';
import '../../../features/jazla/data/repo/jazla_repo_impl.dart';
import '../../storage/key_value_store.dart';

void registerJazlaModule(final GetIt getIt) {
  getIt.registerLazySingleton(
    () => JazlaStore(store: getIt<KeyValueStore>()),
  );
  getIt.registerLazySingleton<JazlaRepo>(
    () => JazlaRepoImpl(store: getIt<JazlaStore>()),
  );
  getIt.registerLazySingleton(() => const JazlaSearchService());
  getIt.registerLazySingleton(() => const JazlaExportService());
}
