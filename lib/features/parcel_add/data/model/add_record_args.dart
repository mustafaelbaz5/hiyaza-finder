import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

/// Navigation arguments for the add-record flow.
class AddRecordArgs {
  const AddRecordArgs({required this.initialParcel, this.parentHoldingId});

  final Parcel initialParcel;
  final String? parentHoldingId;
}
