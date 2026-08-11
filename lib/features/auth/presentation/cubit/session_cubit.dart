import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'session_state.dart';

/// Owns the app-wide auth session. Initializes synchronously from whatever
/// session `supabase_flutter` already restored locally (so there's no
/// splash/loading flicker on a warm start), then stays in sync with
/// [AuthRepository.userChanges] — which is also what catches a forced
/// sign-out (e.g. a refresh token that stops being valid) and reflects it
/// here without any screen having to notice on its own.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._authRepository) : super(_initialState(_authRepository)) {
    _subscription = _authRepository.userChanges.listen(
      (final AppUser? user) {
        emit(
          user == null ? SessionState.unauthenticated() : SessionState.authenticated(user),
        );
      },
      // GoTrue's own background token-refresh timer can fail (e.g. no
      // network) and surface as an error event on this stream rather than a
      // thrown exception any of our own code catches — without this handler
      // it has nowhere to land and is dumped as a raw "Unhandled Exception"
      // to the console. A refresh failure doesn't mean the session is gone
      // (supabase_flutter keeps retrying on its own), so this only logs; it
      // deliberately does not force a sign-out here.
      onError: (final Object error, final StackTrace stackTrace) {
        debugPrint('SessionCubit: userChanges stream error: $error');
      },
    );
  }

  final AuthRepository _authRepository;
  late final StreamSubscription<AppUser?> _subscription;

  static SessionState _initialState(final AuthRepository repo) {
    final AppUser? user = repo.currentUser;
    return user == null ? SessionState.unauthenticated() : SessionState.authenticated(user);
  }

  Future<void> signIn({
    required final String email,
    required final String password,
  }) async {
    emit(state.copyWith(status: SessionStatus.authenticating));
    try {
      final AppUser user = await _authRepository.signInWithPassword(
        email: email,
        password: password,
      );
      emit(SessionState.authenticated(user));
    } on AppException catch (e) {
      emit(
        SessionState.unauthenticated().copyWith(errorMessage: e.message),
      );
    } catch (e) {
      emit(
        SessionState.unauthenticated().copyWith(errorMessage: e.toString()),
      );
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    emit(SessionState.unauthenticated());
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
