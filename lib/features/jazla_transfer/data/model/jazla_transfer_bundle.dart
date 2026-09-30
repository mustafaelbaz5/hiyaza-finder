import '../../../jazla/data/model/jazla.dart';
import '../../../parcel_catalog/data/local/parcel_completion_store.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import 'jazla_transfer_manifest.dart';

class JazlaTransferBundle {
  const JazlaTransferBundle({
    required this.manifest,
    required this.jazla,
    required this.parcels,
    required this.completionStatuses,
  });

  final JazlaTransferManifest manifest;
  final Jazla jazla;
  final List<Parcel> parcels;
  final Map<String, ParcelCompletionStatus> completionStatuses;

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...manifest.toJson(),
        'jazla': jazla.toJson(),
        'parcels':
            parcels.map((final Parcel parcel) => parcel.toJson()).toList(),
        'completionStatuses': completionStatuses.map(
          (final String id, final ParcelCompletionStatus status) =>
              MapEntry<String, dynamic>(id, status.toJson()),
        ),
      };
}
