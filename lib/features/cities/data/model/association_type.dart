/// A city's جمعية type, read directly from `cities.association_type` (a
/// Postgres enum). This is the **authoritative** source — replaces the old
/// `CityType`/`CityTypeDetector` approach that guessed a city's type by
/// scanning parcel data for a matching اسم الجمعية substring. Every record
/// in a given city has always belonged to exactly one system, so this is a
/// per-city property, not something derived per-parcel.
enum AssociationType {
  agriculturalCredit, // الائتمان الزراعي — DB label: agricultural_credit
  agriculturalReform, // الإصلاح الزراعي — DB label: agricultural_reform
}

/// Maps the DB enum's snake_case labels (`agricultural_credit` /
/// `agricultural_reform`) to [AssociationType]. `null`/unrecognized input
/// (including a `NULL` `association_type` column) maps to `null` — callers
/// must handle "type not set yet" explicitly rather than silently guessing,
/// per APP_PLAN.md's "never hide a field that might matter" philosophy.
AssociationType? associationTypeFromString(final String? value) =>
    switch (value) {
      'agricultural_credit' => AssociationType.agriculturalCredit,
      'agricultural_reform' => AssociationType.agriculturalReform,
      _ => null,
    };

/// Inverse of [associationTypeFromString] — used when serializing to the
/// on-device JSON snapshot cache (`CitySnapshotCache`), not for writing
/// back to Supabase (the app never writes `cities` rows).
String associationTypeToString(final AssociationType value) => switch (value) {
      AssociationType.agriculturalCredit => 'agricultural_credit',
      AssociationType.agriculturalReform => 'agricultural_reform',
    };
