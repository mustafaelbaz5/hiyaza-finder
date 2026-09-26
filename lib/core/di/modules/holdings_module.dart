import 'package:get_it/get_it.dart';

import '../../../features/holdings/data/local/bulk_edit_service.dart';
import '../../../features/holdings/data/local/local_added_parcels_store.dart';
import '../../../features/holdings/data/local/local_edit_tracker.dart';
import '../../../features/holdings/data/local/parcel_completion_store.dart';
import '../../../features/holdings/data/local/notes_list_service.dart';
import '../../../features/holdings/data/local/parcel_edit_overlay.dart';
import '../../../features/holdings/data/local/parcel_edits_store.dart';
import '../../../features/holdings/data/local/parcel_query_service.dart';
import '../../../features/holdings/data/local/parcel_id_overrides_store.dart';
import '../../../features/holdings/data/repo/holdings_reader.dart';
import '../../../features/holdings/data/repo/holdings_repository.dart';
import '../../../features/holdings/data/repo/holdings_writer.dart';
import '../../../features/holdings/data/repo/parcel_catalog_session.dart';
import '../../../features/holdings/data/repo/parcel_detail_actions.dart';
import '../../../features/holdings/logic/cubit/parcel_editor_cubit.dart';
import '../../storage/key_value_store.dart';

/// The holdings feature's data layer: the local services `HoldingsRepository`
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
    () => LocalAddedParcelsStore(store: getIt<KeyValueStore>()),
  );
  getIt.registerLazySingleton(
    () => LocalEditTracker(store: getIt<KeyValueStore>()),
  );
  getIt.registerLazySingleton(
    () => ParcelCompletionStore(store: getIt<KeyValueStore>()),
  );
  getIt.registerLazySingleton(
    () => ParcelIdOverridesStore(store: getIt<KeyValueStore>()),
  );
  getIt.registerLazySingleton(
    () => NotesListService(getIt<KeyValueStore>()),
  );

  getIt.registerLazySingleton<HoldingsRepository>(
    () => HoldingsRepository(
      editsStore: getIt(),
      queryService: getIt(),
      editOverlay: getIt(),
      bulkEditService: getIt(),
      addedParcelsStore: getIt(),
      editTracker: getIt(),
      completionStore: getIt(),
      jazlaRepo: getIt(),
      idOverridesStore: getIt(),
    ),
  );
  getIt
      .registerLazySingleton<HoldingsReader>(() => getIt<HoldingsRepository>());
  getIt
      .registerLazySingleton<HoldingsWriter>(() => getIt<HoldingsRepository>());
  getIt.registerLazySingleton<ParcelCatalogSession>(
    () => getIt<HoldingsRepository>(),
  );
  getIt.registerLazySingleton<ParcelDetailActions>(
    () => getIt<HoldingsRepository>(),
  );
  getIt.registerFactory<ParcelEditorCubit>(
    () => ParcelEditorCubit(getIt<HoldingsWriter>()),
  );
}
