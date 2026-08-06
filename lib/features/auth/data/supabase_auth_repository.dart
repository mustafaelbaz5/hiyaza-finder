import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/errors/exceptions.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';
import 'supabase_user_mapper.dart';

/// The only file that touches `Supabase.instance` for auth — everything
/// else depends on [AuthRepository].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AppUser? get currentUser => toAppUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _client.auth.onAuthStateChange
      .map((final AuthState state) => toAppUser(state.session?.user));

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
      final AppUser? user = toAppUser(response.user);
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
