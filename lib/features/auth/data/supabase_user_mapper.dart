import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/app_user.dart';

/// Converts a Supabase Auth [User] into the app's own [AppUser] — extracted
/// from [SupabaseAuthRepository] (pure logic split from the class doing the
/// actual `Supabase.instance` calls) so the display-name fallback and role
/// default are unit-testable without a real/mocked `SupabaseClient`.
///
/// [AppUser.role] is a **client-side default**, not a security decision —
/// the client never grants itself permissions; every table's RLS policy
/// re-checks the caller's role in `profiles` on the server regardless of
/// what this maps to. See `supabase/migrations/20260731000009_rls_policies.sql`.
AppUser? toAppUser(final User? user) {
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
