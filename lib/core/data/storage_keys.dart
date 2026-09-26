/// Canonical keys for generic and city-scoped local persistence.
///
/// Feature stores own their payload shape; this class owns only stable key
/// names so a future migration never has to guess where old data lives.
abstract final class StorageKeys {
  static const String publishedCityCatalog = 'published_city_catalog';

  static String citySchemaVersion(final String cityId) =>
      'city_schema_version::$cityId';

  static String cropTypes(final String cityId) => 'crop_types::$cityId';

  static String jazlas(final String cityId) => 'jazlas::$cityId';

  static String jazlaSort(final String cityId) => 'jazla_sort::$cityId';

  static String addedParcels(final String cityId) => 'added_parcels::$cityId';

  static String editedParcelIds(final String cityId) =>
      'edited_parcel_ids::$cityId';

  static String parcelCompletionStatus(final String cityId) =>
      'parcel_completion_status::$cityId';

  static String parcelIdOverrides(final String cityId) =>
      'parcel_id_overrides::$cityId';

  static String parcelEdits(final String cityId) =>
      'parcel_edits::city::$cityId';
}
