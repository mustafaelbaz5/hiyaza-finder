/// Roles as stored in `profiles.role` — mirrors the `user_role` Postgres
/// enum (`supabase/migrations/20260731000001_enums.sql`).
enum UserRole { admin, editor, viewer, field }

UserRole userRoleFromString(final String value) => switch (value) {
      'admin' => UserRole.admin,
      'editor' => UserRole.editor,
      'viewer' => UserRole.viewer,
      _ => UserRole.field,
    };

/// The signed-in user, as far as the app cares — identity plus the role
/// that gates dashboard-only actions (none exist in the app yet, but the
/// role is already needed to tell staff and field users apart later).
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
}
