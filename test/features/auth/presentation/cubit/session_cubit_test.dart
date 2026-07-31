import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/errors/exceptions.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/auth/presentation/cubit/session_cubit.dart';
import 'package:hiyaza_finder/features/auth/presentation/cubit/session_state.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.initialUser});

  AppUser? initialUser;
  Object? signInError;
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();

  bool signOutCalled = false;

  @override
  AppUser? get currentUser => initialUser;

  @override
  Stream<AppUser?> get userChanges => _controller.stream;

  void emitUser(final AppUser? user) => _controller.add(user);

  @override
  Future<AppUser> signInWithPassword({
    required final String email,
    required final String password,
  }) async {
    if (signInError != null) throw signInError!;
    const AppUser user = AppUser(
      id: 'u1',
      email: 'test@hiyaza.local',
      displayName: 'Test User',
      role: UserRole.field,
    );
    return user;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  void dispose() => _controller.close();
}

void main() {
  test('starts unauthenticated when the repository has no current user', () {
    final _FakeAuthRepository repo = _FakeAuthRepository();
    final SessionCubit cubit = SessionCubit(repo);
    expect(cubit.state.status, SessionStatus.unauthenticated);
    cubit.close();
    repo.dispose();
  });

  test('starts authenticated when the repository already has a session', () {
    const AppUser user = AppUser(
      id: 'u1',
      email: 'a@b.com',
      displayName: 'A',
      role: UserRole.admin,
    );
    final _FakeAuthRepository repo = _FakeAuthRepository(initialUser: user);
    final SessionCubit cubit = SessionCubit(repo);
    expect(cubit.state.status, SessionStatus.authenticated);
    expect(cubit.state.user?.id, 'u1');
    cubit.close();
    repo.dispose();
  });

  test('signIn success emits authenticated with the returned user', () async {
    final _FakeAuthRepository repo = _FakeAuthRepository();
    final SessionCubit cubit = SessionCubit(repo);

    await cubit.signIn(email: 'test@hiyaza.local', password: 'pw');

    expect(cubit.state.status, SessionStatus.authenticated);
    expect(cubit.state.user?.email, 'test@hiyaza.local');
    cubit.close();
    repo.dispose();
  });

  test('signIn failure emits unauthenticated with an error message',
      () async {
    final _FakeAuthRepository repo = _FakeAuthRepository()
      ..signInError = UnauthorizedException(message: 'Invalid email or password.');
    final SessionCubit cubit = SessionCubit(repo);

    await cubit.signIn(email: 'bad@x.com', password: 'wrong');

    expect(cubit.state.status, SessionStatus.unauthenticated);
    expect(cubit.state.errorMessage, 'Invalid email or password.');
    cubit.close();
    repo.dispose();
  });

  test('signOut calls the repository and emits unauthenticated', () async {
    const AppUser user = AppUser(
      id: 'u1',
      email: 'a@b.com',
      displayName: 'A',
      role: UserRole.field,
    );
    final _FakeAuthRepository repo = _FakeAuthRepository(initialUser: user);
    final SessionCubit cubit = SessionCubit(repo);

    await cubit.signOut();

    expect(repo.signOutCalled, isTrue);
    expect(cubit.state.status, SessionStatus.unauthenticated);
    cubit.close();
    repo.dispose();
  });

  test('reacts to userChanges emitting null (forced sign-out)', () async {
    const AppUser user = AppUser(
      id: 'u1',
      email: 'a@b.com',
      displayName: 'A',
      role: UserRole.field,
    );
    final _FakeAuthRepository repo = _FakeAuthRepository(initialUser: user);
    final SessionCubit cubit = SessionCubit(repo);
    expect(cubit.state.status, SessionStatus.authenticated);

    repo.emitUser(null);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.status, SessionStatus.unauthenticated);
    cubit.close();
    repo.dispose();
  });
}
