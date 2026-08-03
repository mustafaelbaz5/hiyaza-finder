import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../sync/presentation/cubit/sync_status_cubit.dart';
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
    _subscription = _authRepository.userChanges.listen((final AppUser? user) {
      emit(
        user == null ? SessionState.unauthenticated() : SessionState.authenticated(user),
      );
      // A session becoming valid here (not just the constructor's warm-start
      // restore, which never reaches this listener) is a real login-adjacent
      // event — e.g. a token refresh coming back after being invalid — so
      // give any queued operations a chance to flush.
      if (user != null) unawaited(_flushSyncSafely());
    });
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
      // `_flushSyncSafely` swallows its own errors, so a sync hiccup can
      // never be mistaken for a failed sign-in by the catch clauses below.
      unawaited(_flushSyncSafely());
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

  Future<void> _flushSyncSafely() async {
    try {
      await getIt<SyncStatusCubit>().flushNow();
    } catch (_) {
      // Sync is a courtesy trigger here, not part of the sign-in contract —
      // never let a sync hiccup surface as an auth error.
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
