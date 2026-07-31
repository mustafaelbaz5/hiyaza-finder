import 'package:get_it/get_it.dart';

import '../../../features/holdings/data/repository/holdings_repository.dart';
import '../../../features/holdings/data/repository/parcel_edits_store.dart';
import '../../../features/holdings/domain/repositories/holdings_reader.dart';
import '../../../features/holdings/domain/repositories/holdings_writer.dart';
import '../../../features/holdings/domain/services/bulk_edit_service.dart';
import '../../../features/holdings/domain/services/parcel_edit_overlay.dart';
import '../../../features/holdings/domain/services/parcel_query_service.dart';
import '../../storage/key_value_store.dart';

/// The holdings feature's data layer: the domain services `HoldingsRepository`
/// composes, and the repository itself, exposed under its `HoldingsReader`/
/// `HoldingsWriter` interfaces as well as its concrete type (screens still
/// reach a few Excel-era-only methods that aren't part of either interface
/// yet — see `APP_PLAN.md` Phase 5 for their retirement).
void registerHoldingsModule(final GetIt getIt) {
  getIt.registerLazySingleton(ParcelQueryService.new);
  getIt.registerLazySingleton(ParcelEditOverlay.new);
  getIt.registerLazySingleton(BulkEditService.new);
  getIt.registerLazySingleton(
    () => ParcelEditsStore(store: getIt<KeyValueStore>()),
  );

  getIt.registerLazySingleton<HoldingsRepository>(
    () => HoldingsRepository(
      editsStore: getIt(),
      keyValueStore: getIt<KeyValueStore>(),
      queryService: getIt(),
      editOverlay: getIt(),
      bulkEditService: getIt(),
    ),
  );
  getIt.registerLazySingleton<HoldingsReader>(() => getIt<HoldingsRepository>());
  getIt.registerLazySingleton<HoldingsWriter>(() => getIt<HoldingsRepository>());
}
