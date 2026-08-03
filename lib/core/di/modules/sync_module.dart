import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/holdings/data/repository/holdings_repository.dart';
import '../../../features/sync/data/realtime_sync_service.dart';
import '../../../features/sync/data/sync_outbox_impl.dart';
import '../../../features/sync/data/sync_runner.dart';
import '../../../features/sync/data/supabase_sync_api.dart';
import '../../../features/sync/domain/repositories/sync_api.dart';
import '../../../features/sync/domain/repositories/sync_queue.dart';
import '../../../features/sync/presentation/cubit/sync_status_cubit.dart';
import '../../networking/network_info.dart';
import '../../storage/key_value_store.dart';

void registerSyncModule(final GetIt getIt) {
  getIt.registerLazySingleton<SyncQueue>(
    () => SyncOutboxImpl(getIt<KeyValueStore>()),
  );
  getIt.registerLazySingleton<SyncApi>(
    () => SupabaseSyncApi(Supabase.instance.client),
  );
  getIt.registerLazySingleton<SyncRunner>(
    () => SyncRunner(
      queue: getIt<SyncQueue>(),
      api: getIt<SyncApi>(),
      authRepository: getIt<AuthRepository>(),
    ),
  );

  // Singleton — one sync status shared across the whole app, same as
  // SessionCubit.
  getIt.registerLazySingleton<SyncStatusCubit>(
    () => SyncStatusCubit(
      queue: getIt<SyncQueue>(),
      runner: getIt<SyncRunner>(),
      networkInfo: getIt<NetworkInfo>(),
    ),
  );

  // Singleton — one Realtime channel manager for the whole app, torn down
  // and re-opened by HoldingsRepository whenever the active city changes.
  getIt.registerLazySingleton<RealtimeSyncService>(
    () => RealtimeSyncService(() => getIt<HoldingsRepository>()),
  );
}
