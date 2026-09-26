import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';

class ParcelIdOverridesStore {
  const ParcelIdOverridesStore({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  final KeyValueStore _store;

  static String _key(final String cityId) => 'parcel_id_overrides::$cityId';

  Future<Map<String, String>> load(final String cityId) async {
    final String? raw = await _store.getString(_key(cityId));
    if (raw == null) return <String, String>{};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (final String key, final dynamic value) => MapEntry(key, value as String),
    );
  }

  Future<void> save(
    final String cityId,
    final String oldId,
    final String newId,
  ) async {
    final Map<String, String> overrides = await load(cityId);
    overrides[oldId] = newId;
    await _store.setString(_key(cityId), jsonEncode(overrides));
  }
}
