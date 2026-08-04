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
    reviewed: row['reviewed'] as bool? ?? false,
    reviewedAt: row['reviewed_at'] == null
        ? null
        : DateTime.parse(row['reviewed_at'] as String),
    reviewedBy: row['reviewed_by'] as String?,
    isFieldAdded: false,
  );
}

/// Converts one raw `added_holdings` row (a field-created record the
/// dashboard has approved) into a [Parcel] — same shape as
/// [holdingRowToParcel] plus the in-app-only fields this table also
/// carries (`owner_name`, `crop_type`, `notes`, `credit_type`,
/// `usage_type`, `is_inheritance`, `is_delegate`). See
/// `supabase/migrations/20260731000007_added_holdings.sql`.
Parcel addedHoldingRowToParcel(final Map<String, dynamic> row) {
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
    ownerName: row['owner_name'] as String?,
    cropType: row['crop_type'] as String?,
    notes: row['notes'] as String?,
    creditType: row['credit_type'] as String? ?? Parcel.defaultCreditType,
    usageType: row['usage_type'] as String? ?? Parcel.defaultUsageType,
    isInheritance: row['is_inheritance'] as bool? ?? false,
    isDelegate: row['is_delegate'] as bool? ?? false,
    reviewed: row['reviewed'] as bool? ?? false,
    reviewedAt: row['reviewed_at'] == null
        ? null
        : DateTime.parse(row['reviewed_at'] as String),
    reviewedBy: row['reviewed_by'] as String?,
    isFieldAdded: true,
  );
}
