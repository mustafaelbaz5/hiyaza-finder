import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';
import '../../../parcel_catalog/data/model/parcel.dart';

class ImportedJazlaParcelStore {
  ImportedJazlaParcelStore({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  final KeyValueStore _store;

  String _key(final String cityId, final String jazlaId) =>
      'jazla_transfer_parcels::$cityId::$jazlaId';

  Future<List<Parcel>> load(final String cityId, final String jazlaId) async {
    final String? raw = await _store.getString(_key(cityId, jazlaId));
    if (raw == null || raw.isEmpty) return const <Parcel>[];
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return const <Parcel>[];
    return decoded
        .whereType<Map>()
        .map(
            (final Map value) => Parcel.fromJson(value.cast<String, dynamic>()))
        .toList();
  }

  Future<void> save(
    final String cityId,
    final String jazlaId,
    final List<Parcel> parcels,
  ) async {
    await _store.setString(
      _key(cityId, jazlaId),
      jsonEncode(
          parcels.map((final Parcel parcel) => parcel.toJson()).toList()),
    );
  }

  Future<void> remove(final String cityId, final String jazlaId) =>
      _store.remove(_key(cityId, jazlaId));
}
