import 'association_type.dart';

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
    this.associationType,
    this.associationSubtype,
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

  /// The city's جمعية system — read directly from `cities.association_type`.
  /// `null` means the dashboard hasn't set it yet for this city; the UI
  /// must degrade gracefully (see `HoldingsRepository.hideCreditType`),
  /// not guess.
  final AssociationType? associationType;

  /// Free-text subtype (e.g. ملك/أوقاف for credit cities, one of the three
  /// إصلاح variants for reform cities) — plain `text` in the DB with no
  /// CHECK constraint, so this can in principle hold any string. Options
  /// shown to the user come from `Parcel.creditTypeOptions`/
  /// `Parcel.reformTypeOptions`, not from this field directly.
  final String? associationSubtype;
}
