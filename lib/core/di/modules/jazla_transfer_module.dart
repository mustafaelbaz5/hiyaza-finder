import 'package:get_it/get_it.dart';

import '../../../features/jazla/data/local/jazla_store.dart';
import '../../../features/jazla_transfer/data/local/imported_jazla_parcel_store.dart';
import '../../../features/jazla_transfer/data/repo/jazla_transfer_repository.dart';
import '../../../features/jazla_transfer/data/repo/jazla_transfer_repository_impl.dart';
import '../../../features/parcel_catalog/data/local/parcel_completion_store.dart';
import '../../storage/key_value_store.dart';

void registerJazlaTransferModule(final GetIt getIt) {
  getIt.registerLazySingleton(
    () => ImportedJazlaParcelStore(store: getIt<KeyValueStore>()),
  );
  getIt.registerLazySingleton<JazlaTransferRepository>(
    () => JazlaTransferRepositoryImpl(
      jazlaStore: getIt<JazlaStore>(),
      completionStore: getIt<ParcelCompletionStore>(),
      importedParcelStore: getIt<ImportedJazlaParcelStore>(),
    ),
  );
}
