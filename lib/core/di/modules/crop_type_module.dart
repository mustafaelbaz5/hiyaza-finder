import 'package:get_it/get_it.dart';

import '../../../features/crop_type/data/local/crop_type_local_ds.dart';
import '../../../features/crop_type/data/repo/crop_type_repo.dart';
import '../../../features/crop_type/data/repo/crop_type_repo_impl.dart';
import '../../storage/key_value_store.dart';

void registerCropTypeModule(final GetIt getIt) {
  getIt.registerLazySingleton<CropTypeLocalDataSource>(
    () => CropTypeLocalDataSource(getIt<KeyValueStore>()),
  );
  getIt.registerLazySingleton<CropTypeRepo>(
    () => CropTypeRepoImpl(getIt<CropTypeLocalDataSource>()),
  );
}
