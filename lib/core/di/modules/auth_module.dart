import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/presentation/cubit/session_cubit.dart';

/// Requires `Supabase.initialize()` to have already run — see main_dev.dart
/// / main_prod.dart, which call it before `setUpDependencies()`.
void registerAuthModule(final GetIt getIt) {
  getIt.registerLazySingleton<AuthRepository>(
    () => SupabaseAuthRepository(Supabase.instance.client),
  );

  // Singleton, not a factory: the whole app shares one session, and
  // SessionCubit's constructor subscribes to the auth stream once.
  getIt.registerLazySingleton<SessionCubit>(
    () => SessionCubit(getIt<AuthRepository>()),
  );
}
