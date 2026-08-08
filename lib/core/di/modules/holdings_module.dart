import 'package:get_it/get_it.dart';

import '../../../features/holdings/data/repository/holdings_repository.dart';
import '../../../features/holdings/data/repository/parcel_edits_store.dart';
import '../../../features/holdings/data/services/add_parcel_sync_handler.dart';
import '../../../features/holdings/data/services/bulk_edit_sync_handler.dart';
import '../../../features/holdings/data/services/complete_parcel_sync_handler.dart';
import '../../../features/holdings/data/services/delete_parcel_sync_handler.dart';
import '../../../features/holdings/data/services/edit_parcel_sync_handler.dart';
import '../../../features/holdings/data/services/parcel_sync_service.dart';
import '../../../features/holdings/domain/repositories/holdings_reader.dart';
import '../../../features/holdings/domain/repositories/holdings_writer.dart';
import '../../../features/holdings/domain/services/bulk_edit_service.dart';
import '../../../features/holdings/domain/services/parcel_edit_overlay.dart';
import '../../../features/holdings/domain/services/parcel_query_service.dart';
import '../../../features/sync/data/holdings_api.dart';
import '../../../features/sync/data/realtime_sync_service.dart';
import '../../../features/sync/domain/entities/sync_operation.dart';
import '../../../features/sync/domain/services/sync_runner.dart';
import '../../networking/network_info.dart';
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
  getIt.registerLazySingleton(
    () => ParcelSyncService(holdingsApi: getIt<HoldingsApi>()),
  );

  // Registers each write kind's execution logic on the shared `SyncRunner`
  // singleton (`REFACTOR_ROADMAP.md` Phase 9 #9) — `holdings` is the
  // feature that owns what each `SyncOperation` type means, per
  // `SYSTEM_DESIGN.md` §5.1's "handler registered by its owning feature"
  // rule; `SyncRunner` itself has zero knowledge of what any of these do.
  getIt<SyncRunner>()
    ..registerHandler(
      AddParcelOperation,
      AddParcelSyncHandler(getIt<ParcelSyncService>()),
    )
    ..registerHandler(
      DeleteParcelOperation,
      DeleteParcelSyncHandler(getIt<HoldingsApi>()),
    )
    ..registerHandler(
      EditParcelOperation,
      EditParcelSyncHandler(getIt<ParcelSyncService>()),
    )
    ..registerHandler(
      CompleteParcelOperation,
      CompleteParcelSyncHandler(getIt<HoldingsApi>()),
    )
    ..registerHandler(
      BulkEditOperation,
      BulkEditSyncHandler(getIt<HoldingsApi>()),
    );

  getIt.registerLazySingleton<HoldingsRepository>(
    () => HoldingsRepository(
      editsStore: getIt(),
      queryService: getIt(),
      editOverlay: getIt(),
      bulkEditService: getIt(),
      holdingsApi: getIt<HoldingsApi>(),
      realtimeSyncService: getIt<RealtimeSyncService>(),
      syncService: getIt<ParcelSyncService>(),
      syncRunner: getIt<SyncRunner>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );
  getIt.registerLazySingleton<HoldingsReader>(() => getIt<HoldingsRepository>());
  getIt.registerLazySingleton<HoldingsWriter>(() => getIt<HoldingsRepository>());
}
