import 'dart:convert';

import '../model/parcel.dart';

import '../../../../core/storage/key_value_store.dart';

/// Persists field-added parcels locally, scoped by city — separate from
/// [ParcelEditsStore] (which tracks edits to existing parcels). Exists so a
/// field worker's new-person/new-parcel writes survive an app restart and
/// are ready for a future export feature, now that the app never writes
/// them to a server.
class LocalAddedParcelsStore {
  const LocalAddedParcelsStore({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  final KeyValueStore _store;

  static String _key(final String cityId) => 'added_parcels::$cityId';

  Future<void> save(final Parcel parcel, final String cityId) async {
    final List<Parcel> current = await loadAll(cityId);
    final List<Parcel> next = <Parcel>[
      for (final Parcel p in current)
        if (p.id != parcel.id) p,
      parcel,
    ];
    await _persist(cityId, next);
  }

  Future<List<Parcel>> loadAll(final String cityId) async {
    final String? raw = await _store.getString(_key(cityId));
    if (raw == null) return const <Parcel>[];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((final dynamic e) => Parcel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> delete(final String parcelId, final String cityId) async {
    final List<Parcel> current = await loadAll(cityId);
    await _persist(
      cityId,
      current.where((final Parcel p) => p.id != parcelId).toList(),
    );
  }

  Future<void> clear(final String cityId) async {
    await _store.remove(_key(cityId));
  }

  Future<Set<String>> loadIds(final String cityId) async {
    final List<Parcel> parcels = await loadAll(cityId);
    return parcels.map((final Parcel p) => p.id).toSet();
  }

  Future<void> _persist(final String cityId, final List<Parcel> parcels) =>
      _store.setString(
        _key(cityId),
        jsonEncode(parcels.map((final Parcel p) => p.toJson()).toList()),
      );
}
