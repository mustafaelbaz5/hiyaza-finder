import 'package:get_it/get_it.dart';

import '../../../features/holdings/data/repository/holdings_repository.dart';
import '../../../features/holdings/data/repository/parcel_edits_store.dart';
import '../../../features/holdings/domain/repositories/holdings_reader.dart';
import '../../../features/holdings/domain/repositories/holdings_writer.dart';
import '../../../features/holdings/domain/services/bulk_edit_service.dart';
import '../../../features/holdings/domain/services/parcel_edit_overlay.dart';
import '../../../features/holdings/domain/services/parcel_query_service.dart';
import '../../../features/sync/data/realtime_sync_service.dart';
import '../../../features/sync/domain/repositories/sync_queue.dart';
import '../../storage/key_value_store.dart';

/// The holdings feature's data layer: the domain services `HoldingsRepository`
/// composes, and the repository itself, exposed under its `HoldingsReader`/
/// `HoldingsWriter` interfaces as well as its concrete type (a few methods,
/// like `addLocalParcel`/`loadParcelsForCity`, aren't part of either
/// interface yet).
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
      queryService: getIt(),
      editOverlay: getIt(),
      bulkEditService: getIt(),
      syncQueue: getIt<SyncQueue>(),
      realtimeSyncService: getIt<RealtimeSyncService>(),
    ),
  );
  getIt.registerLazySingleton<HoldingsReader>(() => getIt<HoldingsRepository>());
  getIt.registerLazySingleton<HoldingsWriter>(() => getIt<HoldingsRepository>());
}
