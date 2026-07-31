import '../../holdings/domain/entities/parcel.dart';

/// Converts one raw `holdings` table row (Postgrest's
/// `Map&lt;String, dynamic&gt;` shape, snake_case columns) into the base
/// [Parcel] before any local edits are overlaid on top. See
/// `supabase/migrations/20260731000005_holdings.sql` for the column list
/// and `APP_PLAN.md` § "Sample Excel structure" for where each one
/// originally comes from.
Parcel holdingRowToParcel(final Map<String, dynamic> row) {
  double? asDouble(final dynamic value) =>
      value == null ? null : (value as num).toDouble();

  return Parcel(
    id: row['id'] as String,
    holdingId: (row['holding_id_number'] as String?) ?? '',
    pageNumber: row['page_number'] as String?,
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
    feddan: asDouble(row['feddan']),
    qirat: asDouble(row['qirat']),
    sahm: asDouble(row['sahm']),
    totalSqm: asDouble(row['total_sqm']),
    associationName: row['association_name'] as String?,
  );
}
