import '../entities/app_user.dart';

/// Auth contract the presentation layer depends on — no `supabase_flutter`
/// import here, so `SessionCubit` is testable against a fake without a
/// network or a real Supabase client.
abstract class AuthRepository {
  /// The signed-in user right now, synchronously — backed by the locally
  /// persisted session `supabase_flutter` restores before the app builds
  /// its first frame, so this never needs to be awaited at startup.
  AppUser? get currentUser;

  /// Emits whenever the session changes (sign in, sign out, token refresh
  /// that fails and forces a sign-out).
  Stream<AppUser?> get userChanges;

  Future<AppUser> signInWithPassword({
    required final String email,
    required final String password,
  });

  Future<void> signOut();
}
