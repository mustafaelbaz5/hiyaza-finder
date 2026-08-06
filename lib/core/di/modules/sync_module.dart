import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/holdings/data/repository/holdings_repository.dart';
import '../../../features/sync/data/holdings_api.dart';
import '../../../features/sync/data/realtime_sync_service.dart';
import '../../../features/sync/data/sync_queue_store.dart';
import '../../../features/sync/domain/services/sync_runner.dart';

void registerSyncModule(final GetIt getIt) {
  getIt.registerLazySingleton<HoldingsApi>(
    () => HoldingsApi(Supabase.instance.client),
  );

  // Singleton — one Realtime channel manager for the whole app, torn down
  // and re-opened by HoldingsRepository whenever the active city changes.
  getIt.registerLazySingleton<RealtimeSyncService>(
    () => RealtimeSyncService(() => getIt<HoldingsRepository>()),
  );

  // The outbox queue's durable-storage half (`REFACTOR_ROADMAP.md` Phase 9
  // #9) — `SyncQueueStore` persists what `SyncRunner` holds in memory so a
  // pending write survives an app restart, not just a screen navigation.
  getIt.registerLazySingleton(SyncQueueStore.new);

  // Singleton — one outbox for the whole app; handlers are registered by
  // `registerHoldingsModule` (the feature that owns what each operation
  // type means), and the queue is restored from durable storage once, at
  // `hiyaza_finder_app.dart`'s startup sequence.
  getIt.registerLazySingleton(SyncRunner.new);
}
