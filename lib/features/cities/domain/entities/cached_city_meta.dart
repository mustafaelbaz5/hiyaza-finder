/// Lightweight summary of a city snapshot already on disk — what the
/// "manage downloaded cities" screen lists, without paying the cost of
/// mapping every cached row through `Parcel.fromJson` just to show a size.
class CachedCityMeta {
  const CachedCityMeta({
    required this.cityId,
    required this.cityName,
    required this.dataVersion,
    required this.downloadedAt,
    required this.holdingsCount,
    required this.fileSizeBytes,
  });

  final String cityId;
  final String cityName;
  final int dataVersion;
  final DateTime downloadedAt;
  final int holdingsCount;
  final int fileSizeBytes;
}
