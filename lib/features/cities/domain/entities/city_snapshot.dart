import '../../../holdings/domain/entities/parcel.dart';
import 'city_type.dart';

/// A downloaded-and-cached city dataset — what the app actually works
/// from offline once a city has been picked. [dataVersion] is what the
/// staleness check compares against the server's current
/// `cities.data_version`. [cityType] is detected once at download time
/// (`CityTypeDetector`) and cached here so it never needs recomputing
/// from the full parcel list on every subsequent load.
class CitySnapshot {
  const CitySnapshot({
    required this.cityId,
    required this.cityName,
    required this.dataVersion,
    required this.downloadedAt,
    required this.parcels,
    this.cityType = CityType.unspecified,
  });

  final String cityId;
  final String cityName;
  final int dataVersion;
  final DateTime downloadedAt;
  final List<Parcel> parcels;
  final CityType cityType;
}
