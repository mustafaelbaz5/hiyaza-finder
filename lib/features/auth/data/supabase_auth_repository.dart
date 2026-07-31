import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/errors/exceptions.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

/// The only file that touches `Supabase.instance` for auth — everything
/// else depends on [AuthRepository].
///
/// [AppUser.role] here is a **client-side default**, not a security
/// decision — the client never grants itself permissions; every table's
/// RLS policy re-checks the caller's role in `profiles` on the server
/// regardless of what this object says. See
/// `supabase/migrations/20260731000009_rls_policies.sql`.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  AppUser? _toAppUser(final User? user) {
    if (user == null) return null;
    final String? displayName = user.userMetadata?['display_name'] as String?;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: (displayName == null || displayName.isEmpty)
          ? (user.email ?? '')
          : displayName,
      role: UserRole.field,
    );
  }

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _client.auth.onAuthStateChange
      .map((final AuthState state) => _toAppUser(state.session?.user));

  @override
  Future<AppUser> signInWithPassword({
    required final String email,
    required final String password,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final AppUser? user = _toAppUser(response.user);
      if (user == null) {
        throw UnauthorizedException(message: 'Invalid email or password.');
      }
      return user;
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }
}
