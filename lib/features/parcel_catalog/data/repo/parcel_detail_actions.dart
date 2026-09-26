import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

/// Mutations available only from an opened parcel-detail flow.
///
/// The detail UI requests an intent through this port and never learns about
/// repository, local storage, or Jazla-reference coordination details.
abstract class ParcelDetailActions {
  Future<bool> deleteLocalParcel(final String parcelId);

  Future<Parcel?> setParcelCompleted(
    final String parcelId, {
    required final bool completed,
  });

  Future<Parcel?> regenerateLocalParcelId(final String parcelId);
}
