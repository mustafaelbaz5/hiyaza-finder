/// Which agricultural system a city's holdings belong to — every record
/// in a given city carries the same اسم الجمعية suffix, so a city is
/// always entirely one type or the other. Drives whether نوع الائتمان is
/// shown anywhere in the app (only meaningful for `agriculturalCredit`).
enum CityType {
  agriculturalReform, // الإصلاح الزراعي
  agriculturalCredit, // الائتمان الزراعي

  /// No parcel's اسم الجمعية matched either known system — an unrecognized
  /// or empty dataset. Treated like `agriculturalCredit` everywhere (shows
  /// نوع الائتمان) so a detection miss never silently hides a field that
  /// might matter.
  unspecified,
}

CityType cityTypeFromString(final String? value) => switch (value) {
      'agriculturalReform' => CityType.agriculturalReform,
      'agriculturalCredit' => CityType.agriculturalCredit,
      _ => CityType.unspecified,
    };
