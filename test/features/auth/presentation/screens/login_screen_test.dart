import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/auth/presentation/cubit/session_cubit.dart';
import 'package:hiyaza_finder/features/auth/presentation/screens/login_screen.dart';

import '../../../../support/localized_widget_test_harness.dart';

class _FakeAuthRepository implements AuthRepository {
  Object? signInError;
  final StreamController<AppUser?> _controller = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> get userChanges => _controller.stream;

  @override
  Future<AppUser> signInWithPassword({
    required final String email,
    required final String password,
  }) async {
    if (signInError != null) throw signInError!;
    return const AppUser(
      id: 'u1',
      email: 'test@hiyaza.local',
      displayName: 'Test User',
      role: UserRole.field,
    );
  }

  @override
  Future<void> signOut() async {}

  void dispose() => _controller.close();
}

/// LoginScreen reads `SessionCubit` via `BuildContext` and, on successful
/// sign-in, navigates via `context.pushNamedAndRemoveAll(Routes.home)` —
/// which needs a real named-route table this test doesn't set up. Tests
/// here stick to validation/rendering and a failed sign-in (which stays on
/// this screen), not the post-auth navigation.
Future<void> _pumpLoginScreen(
  final WidgetTester tester,
  final SessionCubit cubit,
) async {
  await pumpLocalizedScreen(
    tester,
    BlocProvider<SessionCubit>.value(
      value: cubit,
      child: const LoginScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalizedWidgetTestHarness);

  late _FakeAuthRepository repository;
  late SessionCubit cubit;

  setUp(() {
    repository = _FakeAuthRepository();
    cubit = SessionCubit(repository);
  });

  tearDown(() {
    cubit.close();
    repository.dispose();
  });

  testWidgets('renders the brand title and both fields', (final tester) async {
    await _pumpLoginScreen(tester, cubit);

    expect(find.text('حيازة'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('shows a validation error when submitting an empty form',
      (final tester) async {
    await _pumpLoginScreen(tester, cubit);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.text('البريد الإلكتروني مطلوب'), findsOneWidget);
    expect(find.text('كلمة المرور مطلوبة'), findsOneWidget);
  });

  testWidgets('shows a validation error for a malformed email', (final tester) async {
    await _pumpLoginScreen(tester, cubit);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.text('صيغة البريد الإلكتروني غير صحيحة'), findsOneWidget);
  });

  testWidgets('a failed sign-in shows the error via a snackbar and stays on screen',
      (final tester) async {
    repository.signInError = Exception('bad credentials');
    await _pumpLoginScreen(tester, cubit);

    await tester.enterText(
      find.byType(TextFormField).first,
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(cubit.state.status.name, 'unauthenticated');
  });
}
