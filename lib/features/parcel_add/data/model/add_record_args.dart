import '../../../parcel_catalog/data/model/parcel.dart';

/// Navigation arguments for the add-record flow.
class AddRecordArgs {
  const AddRecordArgs({
    required this.initialParcel,
    this.parentHoldingId,
    this.suggestedBasinName,
    this.suggestedBasinCode,
  });

  final Parcel initialParcel;
  final String? parentHoldingId;

  /// A non-binding basin suggestion supplied by the opening flow. Jazla uses
  /// this to start a record in its basin while the user can still change it.
  final String? suggestedBasinName;
  final String? suggestedBasinCode;
}
