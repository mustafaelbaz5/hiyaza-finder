import '../../../../core/storage/key_value_store.dart';

enum JazlaSort { newest, updated, name, parcelCount }

class JazlaPreferences {
  const JazlaPreferences({final KeyValueStore store = const SharedPreferencesKeyValueStore()}) : _store = store;
  final KeyValueStore _store;

  String _key(final String cityId) => 'jazla_sort::$cityId';

  Future<JazlaSort> loadSort(final String cityId) async {
    final String? value = await _store.getString(_key(cityId));
    return JazlaSort.values.firstWhere(
      (final JazlaSort sort) => sort.name == value,
      orElse: () => JazlaSort.newest,
    );
  }

  Future<void> saveSort(final String cityId, final JazlaSort sort) =>
      _store.setString(_key(cityId), sort.name);
}
