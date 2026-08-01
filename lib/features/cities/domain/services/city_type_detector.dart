import '../../../holdings/domain/entities/parcel.dart';
import '../entities/city_type.dart';

/// Determines a city's [CityType] from its downloaded dataset — every
/// parcel's اسم الجمعية carries the same "- الإصلاح الزراعي" /
/// "- الائتمان الزراعي" suffix, so the first parcel with a recognizable
/// value settles it for the whole city. Generic by design: works for any
/// city, current or future, with no per-city hardcoding — the only
/// per-city input is the data itself.
class CityTypeDetector {
  const CityTypeDetector._();

  static const String _reformMarker = 'الإصلاح الزراعي';
  static const String _creditMarker = 'الائتمان الزراعي';

  /// Stops at the first parcel whose اسم الجمعية matches a known system —
  /// no need to scan the rest of a potentially large dataset once one
  /// record has settled it.
  static CityType detect(final List<Parcel> parcels) {
    for (final Parcel p in parcels) {
      final String? name = p.associationName;
      if (name == null || name.isEmpty) continue;
      if (name.contains(_reformMarker)) return CityType.agriculturalReform;
      if (name.contains(_creditMarker)) return CityType.agriculturalCredit;
    }
    return CityType.unspecified;
  }
}
