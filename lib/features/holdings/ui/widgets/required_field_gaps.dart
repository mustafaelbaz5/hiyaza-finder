import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/parcel.dart';

/// One localized line per required field [parcel] is still missing, in the
/// same order as [Parcel.hasRequiredFieldsFilled]'s checks. Shared by
/// `AddRecordScreen`'s save gate and `ParcelDetailCard`'s Copy ID
/// review-completion gate (`REFACTOR_ROADMAP.md` Phase 7) — kept in the UI
/// layer (not on [Parcel] itself) because `.tr()` needs `easy_localization`,
/// which the pure-Dart domain entity can't import.
List<String> requiredFieldGapMessages(final Parcel parcel) => <String>[
      if (!Parcel.isHoldingIdExplicitlyEntered(parcel.holdingId))
        'holdings.add.holding_id_required'.tr(),
      if (!Parcel.isValueFilled(parcel.holderName))
        'holdings.add.holder_required'.tr(),
      if (!Parcel.isValueFilled(parcel.basinName))
        'holdings.add.basin_required'.tr(),
      if (!Parcel.isValueFilled(parcel.cropType))
        'holdings.add.crop_type_required'.tr(),
      if (!Parcel.isAreaFilled(
        feddan: parcel.feddan,
        qirat: parcel.qirat,
        sahm: parcel.sahm,
      ))
        'holdings.add.area_required'.tr(),
      if (!Parcel.isNationalIdValid(parcel.nationalId))
        'holdings.add.national_id_invalid'.tr(),
    ];
