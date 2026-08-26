import '../model/jazla.dart';

/// Write/read contract for Jazlas — deliberately never accepts or returns a
/// `Parcel`. "الجزلة لا تحتوي بيانات — هي تحتوي IDs فقط" is enforced by this
/// interface's type signature, not just convention: resolving `parcelIds` to
/// actual [Parcel] objects is the caller's (cubit's) job via `HoldingsReader`.
abstract class JazlaRepo {
  Future<List<Jazla>> getAll(final String cityId);

  Future<Jazla> create(final String name, final String cityId);

  Future<void> delete(final String jazlaId, final String cityId);

  Future<void> rename(
    final String jazlaId,
    final String newName,
    final String cityId,
  );

  Future<void> addParcel(
    final String jazlaId,
    final String parcelId,
    final String cityId,
  );

  Future<void> removeParcel(
    final String jazlaId,
    final String parcelId,
    final String cityId,
  );

  Future<void> reorderParcels(
    final String jazlaId,
    final List<String> newOrder,
    final String cityId,
  );

  Future<Jazla?> getJazlaContaining(final String parcelId, final String cityId);

  Future<bool> isParcelUsed(final String parcelId, final String cityId);
}
