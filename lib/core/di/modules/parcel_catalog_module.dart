import 'package:get_it/get_it.dart';

import '../../../features/parcel_catalog/data/local/bulk_edit_service.dart';
import '../../../features/parcel_catalog/data/local/local_added_parcels_store.dart';
import '../../../features/parcel_catalog/data/local/local_edit_tracker.dart';
import '../../../features/parcel_catalog/data/local/parcel_completion_store.dart';
import '../../../features/parcel_review/data/local/notes_list_service.dart';
import '../../../features/parcel_catalog/data/local/parcel_edit_overlay.dart';
import '../../../features/parcel_catalog/data/local/parcel_edits_store.dart';
import '../../../features/parcel_catalog/data/local/parcel_query_service.dart';
import '../../../features/parcel_catalog/data/local/parcel_id_overrides_store.dart';
import '../../../features/parcel_catalog/data/repo/holdings_reader.dart';
import '../../../features/parcel_catalog/data/repo/parcel_catalog_repository.dart';
import '../../../features/parcel_catalog/data/repo/holdings_writer.dart';
import '../../../features/parcel_catalog/data/repo/parcel_catalog_session.dart';
import '../../../features/parcel_catalog/data/repo/parcel_detail_actions.dart';
import '../../../features/parcel_editor/logic/cubit/parcel_editor_cubit.dart';
import '../../storage/key_value_store.dart';

/// The parcel catalog data layer: the local services
/// `ParcelCatalogRepository` composes, exposed through narrow contracts.
/// A few lifecycle methods,
/// like `addLocalParcel`/`loadParcelsForCity`, aren't part of either
/// interface yet).
void registerParcelCatalogModule(final GetIt getIt) {
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

  getIt.registerLazySingleton<ParcelCatalogRepository>(
    () => ParcelCatalogRepository(
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
  getIt.registerLazySingleton<ParcelCatalogReader>(
    () => getIt<ParcelCatalogRepository>(),
  );
  getIt.registerLazySingleton<ParcelCatalogWriter>(
    () => getIt<ParcelCatalogRepository>(),
  );
  getIt.registerLazySingleton<ParcelCatalogSession>(
    () => getIt<ParcelCatalogRepository>(),
  );
  getIt.registerLazySingleton<ParcelDetailActions>(
    () => getIt<ParcelCatalogRepository>(),
  );

  getIt.registerFactory<ParcelEditorCubit>(
    () => ParcelEditorCubit(getIt<ParcelCatalogWriter>()),
  );
}
