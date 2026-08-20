

import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

/// Builds the `added_holdings` insert shape (snake_case columns) from a
/// [Parcel] built in the add-person/add-parcel form. Excludes columns the
/// sync runner fills in itself (`city_id`, `client_id`, `parent_holding_id`,
/// `created_by`) — see `supabase/migrations/20260731000007_added_holdings.sql`.
Map<String, dynamic> parcelToAddedHoldingsRecord(final Parcel p) {
  return <String, dynamic>{
    // Sent as the literal value the user left/typed in the field — even a
    // placeholder like "-1" — not converted to null. `isHoldingIdPending`
    // is only for app-side grouping/badge concerns; the server payload
    // reflects exactly what's shown in the form.
    'holding_id_number': p.holdingId.trim().isEmpty ? null : p.holdingId.trim(),
    'person_id': p.personId,
    'holder_name': p.holderName,
    'owner_name': p.ownerName,
    'national_id': p.nationalId,
    'land_number': p.landNumber,
    'page_number': p.pageNumber,
    'basin_name': p.basinName,
    'basin_code': p.basinCode,
    'association_name': p.associationName,
    'administration': p.administration,
    'directorate': p.directorate,
    'border_east': p.borderEast,
    'border_west': p.borderWest,
    'border_south': p.borderSouth,
    'border_north': p.borderNorth,
    // `added_holdings.feddan/qirat/sahm` are `not null numeric(10,4)` —
    // fractional فدان values round-trip fine as-is (no `.round()` needed,
    // unlike an actual `int` column), but a `null` value still needs the
    // `?? 0` fallback since the column itself is NOT NULL. The area edit
    // dialog (`field_edit_dialogs.dart`) already rejects a value at or
    // above 999999.9999 before it reaches here.
    'feddan': p.feddan ?? 0,
    'qirat': p.qirat ?? 0,
    'sahm': p.sahm ?? 0,
    'total_sqm': p.totalSqm,
    'crop_type': p.cropType,
    'notes': p.notes,
    'credit_type': p.creditType,
    'usage_type': p.usageType,
    'is_inheritance': p.isInheritance,
    'is_delegate': p.isDelegate,
    'holder_name_farmer_card': p.holderNameFarmerCard,
    'owner_name_farmer_card': p.ownerNameFarmerCard,
    'growth_stages': p.growthStages,
  };
}
