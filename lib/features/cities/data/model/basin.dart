/// One row of the `basins` table — a حوض within a city, with its
/// pre-aggregated totals/count computed server-side. Downloaded alongside
/// [Parcel]s in the same city-download request, never fetched separately.
class Basin {
  const Basin({
    required this.id,
    required this.cityId,
    required this.basinName,
    required this.parcelCount,
    this.basinCode,
    this.totalFeddan = 0,
    this.totalQirat = 0,
    this.totalSahm = 0,
    this.totalSqm = 0,
  });

  final String id;
  final String cityId;
  final String basinName;
  final String? basinCode;
  final double totalFeddan;
  final double totalQirat;
  final double totalSahm;
  final double totalSqm;
  final int parcelCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cityId': cityId,
        'basinName': basinName,
        'basinCode': basinCode,
        'totalFeddan': totalFeddan,
        'totalQirat': totalQirat,
        'totalSahm': totalSahm,
        'totalSqm': totalSqm,
        'parcelCount': parcelCount,
      };

  factory Basin.fromJson(final Map<String, dynamic> json) {
    double d(final String key) => (json[key] as num?)?.toDouble() ?? 0;
    return Basin(
      id: json['id'] as String,
      cityId: json['cityId'] as String,
      basinName: json['basinName'] as String,
      basinCode: json['basinCode'] as String?,
      totalFeddan: d('totalFeddan'),
      totalQirat: d('totalQirat'),
      totalSahm: d('totalSahm'),
      totalSqm: d('totalSqm'),
      parcelCount: json['parcelCount'] as int? ?? 0,
    );
  }
}

/// Converts one raw `basins` table row into a [Basin].
Basin basinRowToBasin(final Map<String, dynamic> row) {
  double d(final String key) => (row[key] as num?)?.toDouble() ?? 0;
  return Basin(
    id: row['id'] as String,
    cityId: row['city_id'] as String,
    basinName: row['basin_name'] as String,
    basinCode: row['basin_code'] as String?,
    totalFeddan: d('total_feddan'),
    totalQirat: d('total_qirat'),
    totalSahm: d('total_sahm'),
    totalSqm: d('total_sqm'),
    parcelCount: (row['parcel_count'] as num?)?.toInt() ?? 0,
  );
}
