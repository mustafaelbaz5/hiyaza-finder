import '../model/parcel.dart';

/// Converts one raw `parcels` table row (Postgrest's `Map<String, dynamic>`
/// shape, snake_case columns) into the base [Parcel] before any local edits
/// are overlaid on top. Every field-worker-entered value (owner_name,
/// crop_type, notes, toggles, completion) is local-only — none of it is a
/// remote column on this schema, so this mapper only ever sets [Parcel]'s
/// read-only/imported fields; everything else keeps its constructor default
/// until the local edit overlay is applied on top.
Parcel parcelRowToParcel(final Map<String, dynamic> row) {
  double? asDouble(final dynamic value) =>
      value == null ? null : (value as num).toDouble();

  return Parcel(
    id: row['id'] as String,
    holdingId: (row['holding_id_number'] as String?) ?? '',
    directorate: row['directorate'] as String?,
    administration: row['administration'] as String?,
    basinName: row['basin_name'] as String?,
    basinCode: row['basin_code'] as String?,
    holderName: row['holder_name'] as String?,
    nationalId: row['national_id'] as String?,
    borderEast: row['border_east'] as String?,
    borderSouth: row['border_south'] as String?,
    borderWest: row['border_west'] as String?,
    borderNorth: row['border_north'] as String?,
    landNumber: row['land_number'] as String?,
    feddan: asDouble(row['area_feddan']),
    qirat: asDouble(row['area_qirat']),
    sahm: asDouble(row['area_sahm']),
    totalSqm: asDouble(row['area_sqm']),
    associationName: row['association_name'] as String?,
    holdingsCount: (row['parcel_count_in_holding'] as num?)?.toInt(),
  );
}
