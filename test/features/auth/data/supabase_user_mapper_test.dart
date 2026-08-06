import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/auth/data/supabase_user_mapper.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user({
  final String id = 'u1',
  final String? email = 'user@example.com',
  final Map<String, dynamic>? userMetadata,
}) =>
    User(
      id: id,
      appMetadata: const <String, dynamic>{},
      userMetadata: userMetadata,
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: email,
    );

void main() {
  group('toAppUser', () {
    test('returns null for a null user', () {
      expect(toAppUser(null), isNull);
    });

    test('maps id/email and defaults role to field', () {
      final AppUser? result = toAppUser(_user(id: 'u1', email: 'a@b.com'));

      expect(result, isNotNull);
      expect(result!.id, 'u1');
      expect(result.email, 'a@b.com');
      expect(result.role, UserRole.field);
    });

    test('uses display_name from userMetadata when present', () {
      final AppUser? result = toAppUser(
        _user(
          email: 'a@b.com',
          userMetadata: const <String, dynamic>{'display_name': 'محمد علي'},
        ),
      );

      expect(result!.displayName, 'محمد علي');
    });

    test('falls back to email when display_name is missing', () {
      final AppUser? result = toAppUser(_user(email: 'a@b.com'));

      expect(result!.displayName, 'a@b.com');
    });

    test('falls back to email when display_name is an empty string', () {
      final AppUser? result = toAppUser(
        _user(
          email: 'a@b.com',
          userMetadata: const <String, dynamic>{'display_name': ''},
        ),
      );

      expect(result!.displayName, 'a@b.com');
    });

    test('email defaults to an empty string when the user has none', () {
      final AppUser? result = toAppUser(_user(email: null));

      expect(result!.email, '');
      expect(result.displayName, ''); // falls back to the empty email too
    });
  });
}
