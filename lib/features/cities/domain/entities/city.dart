/// Mirrors the `city_status` Postgres enum
/// (`supabase/migrations/20260731000001_enums.sql`).
enum CityStatus { draft, published, archived }

CityStatus cityStatusFromString(final String value) => switch (value) {
      'published' => CityStatus.published,
      'archived' => CityStatus.archived,
      _ => CityStatus.draft,
    };

/// A city/جمعية the app can download a dataset for. Only `published`
/// cities are ever offered to the app (enforced both here — the query
/// only asks for published cities — and server-side by RLS).
class City {
  const City({
    required this.id,
    required this.name,
    required this.status,
    required this.dataVersion,
    this.directorate,
    this.administration,
  });

  final String id;
  final String name;
  final String? directorate;
  final String? administration;
  final CityStatus status;

  /// Bumped by the server on any data change for this city — compared
  /// against a locally cached snapshot's stored version to detect
  /// staleness. See `bump_city_version*` triggers in
  /// `supabase/migrations/20260731000008_triggers.sql`.
  final int dataVersion;
}
