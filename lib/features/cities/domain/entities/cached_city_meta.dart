/// Lightweight summary of a city snapshot already on disk — what the
/// "manage downloaded cities" screen lists, without paying the cost of
/// mapping every cached row through `Parcel.fromJson` just to show a size.
class CachedCityMeta {
  const CachedCityMeta({
    required this.cityId,
    required this.cityName,
    required this.dataVersion,
    required this.downloadedAt,
    required this.parcelsCount,
    required this.fileSizeBytes,
  });

  final String cityId;
  final String cityName;
  final int dataVersion;
  final DateTime downloadedAt;

  /// Raw row count in the cached snapshot — one row per **parcel** (قطعة),
  /// not per distinct holding (حيازة). A single holding can span several
  /// parcels, so this is always ≥ the home screen's `HomeState.holdingCount`
  /// (which counts distinct `Parcel.groupKey`s). Kept as a raw count here
  /// since that's what maps 1:1 to file size without re-parsing every row.
  final int parcelsCount;
  final int fileSizeBytes;
}
