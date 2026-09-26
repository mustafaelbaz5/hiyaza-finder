import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/usage_type.dart';

/// Rules for copying a parcel's data. Copying is deliberately separate from
/// completion: a worker must be able to copy an ID even while a record is
/// still incomplete.
class CopyValidation {
  const CopyValidation._();

  static bool canCopyAll(final Parcel parcel) {
    final bool hasArea = Parcel.isAreaFilled(
      feddan: parcel.feddan,
      qirat: parcel.qirat,
      sahm: parcel.sahm,
    );
    if (!hasArea) return false;

    final bool agricultural =
        UsageType.fromLabel(parcel.usageType) == UsageType.agricultural;
    return !agricultural || Parcel.isValueFilled(parcel.cropType);
  }

  static bool canMarkCompleted(final Parcel parcel) {
    final bool baseFieldsFilled =
        Parcel.isHoldingIdExplicitlyEntered(parcel.holdingId) &&
            Parcel.isValueFilled(parcel.holderName) &&
            Parcel.isValueFilled(parcel.basinName) &&
            Parcel.isAreaFilled(
              feddan: parcel.feddan,
              qirat: parcel.qirat,
              sahm: parcel.sahm,
            ) &&
            Parcel.isNationalIdValid(parcel.nationalId);
    if (!baseFieldsFilled) return false;

    final bool agricultural =
        UsageType.fromLabel(parcel.usageType) == UsageType.agricultural;
    return !agricultural || Parcel.isValueFilled(parcel.cropType);
  }
}
