import '../model/parcel.dart';
import '../model/parcel_activity_status.dart';

/// The one authoritative area-based classification rule for parcel views.
///
/// `totalSqm` deliberately does not participate because it is calculated
/// from the three agricultural units and must not disagree with them.
class ParcelActivityClassifier {
  const ParcelActivityClassifier();

  ParcelActivityStatus classify(final Parcel parcel) => isActive(parcel)
      ? ParcelActivityStatus.active
      : ParcelActivityStatus.zeroArea;

  bool isActive(final Parcel parcel) =>
      (parcel.feddan ?? 0) > 0 ||
      (parcel.qirat ?? 0) > 0 ||
      (parcel.sahm ?? 0) > 0;

  bool isZeroArea(final Parcel parcel) => !isActive(parcel);
}
