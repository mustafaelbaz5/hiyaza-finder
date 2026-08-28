import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart';
import '../local/jazla_store.dart';
import '../model/jazla.dart';
import 'jazla_repo.dart';

class JazlaRepoImpl implements JazlaRepo {
  JazlaRepoImpl({required final JazlaStore store}) : _store = store;

  final JazlaStore _store;
  static const Uuid _uuid = Uuid();

  @override
  Future<List<Jazla>> getAll(final String cityId) => _store.load(cityId);

  @override
  Future<Jazla> create(final String name, final String cityId) async {
    final List<Jazla> jazlas = await _store.load(cityId);
    final Jazla created = Jazla(
      id: _uuid.v4(),
      cityId: cityId,
      name: name,
      createdAt: DateTime.now(),
    );
    await _store.save(cityId, <Jazla>[...jazlas, created]);
    return created;
  }

  @override
  Future<void> delete(final String jazlaId, final String cityId) async {
    final List<Jazla> jazlas = await _store.load(cityId);
    await _store.save(
      cityId,
      jazlas.where((final Jazla j) => j.id != jazlaId).toList(),
    );
  }

  @override
  Future<void> rename(
    final String jazlaId,
    final String newName,
    final String cityId,
  ) =>
      _mutate(cityId, jazlaId, (final Jazla j) => j.copyWith(name: newName));

  @override
  Future<void> addParcel(
    final String jazlaId,
    final String parcelId,
    final String cityId,
  ) async {
    if (await isParcelUsed(parcelId, cityId)) {
      throw CacheException(
        message: 'Parcel $parcelId is already in another Jazla.',
      );
    }
    await _mutate(
      cityId,
      jazlaId,
      (final Jazla j) => j.copyWith(parcelIds: <String>[...j.parcelIds, parcelId]),
    );
  }

  @override
  Future<void> removeParcel(
    final String jazlaId,
    final String parcelId,
    final String cityId,
  ) =>
      _mutate(
        cityId,
        jazlaId,
        (final Jazla j) => j.copyWith(
          parcelIds:
              j.parcelIds.where((final String id) => id != parcelId).toList(),
        ),
      );

  @override
  Future<void> reorderParcels(
    final String jazlaId,
    final List<String> newOrder,
    final String cityId,
  ) =>
      _mutate(cityId, jazlaId, (final Jazla j) => j.copyWith(parcelIds: newOrder));

  @override
  Future<Jazla?> getJazlaContaining(
    final String parcelId,
    final String cityId,
  ) async {
    final List<Jazla> jazlas = await _store.load(cityId);
    for (final Jazla j in jazlas) {
      if (j.parcelIds.contains(parcelId)) return j;
    }
    return null;
  }

  @override
  Future<bool> isParcelUsed(final String parcelId, final String cityId) async =>
      await getJazlaContaining(parcelId, cityId) != null;

  Future<void> _mutate(
    final String cityId,
    final String jazlaId,
    final Jazla Function(Jazla) update,
  ) async {
    final List<Jazla> jazlas = await _store.load(cityId);
    final List<Jazla> updated = jazlas
        .map((final Jazla j) => j.id == jazlaId ? update(j) : j)
        .toList();
    await _store.save(cityId, updated);
  }
}
