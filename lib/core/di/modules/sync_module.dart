import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/holdings/data/repository/holdings_repository.dart';
import '../../../features/sync/data/holdings_api.dart';
import '../../../features/sync/data/realtime_sync_service.dart';

void registerSyncModule(final GetIt getIt) {
  getIt.registerLazySingleton<HoldingsApi>(
    () => HoldingsApi(Supabase.instance.client),
  );

  // Singleton — one Realtime channel manager for the whole app, torn down
  // and re-opened by HoldingsRepository whenever the active city changes.
  getIt.registerLazySingleton<RealtimeSyncService>(
    () => RealtimeSyncService(() => getIt<HoldingsRepository>()),
  );
}
