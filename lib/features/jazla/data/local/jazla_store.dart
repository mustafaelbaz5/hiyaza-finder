import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';
import '../model/jazla.dart';

/// Local per-city persistence for every [Jazla] — one JSON array per city,
/// mirroring `ParcelEditsStore`'s load-all/save-all shape rather than a
/// store method per mutation; list mutation itself lives in `JazlaRepoImpl`.
class JazlaStore {
  const JazlaStore({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  final KeyValueStore _store;

  static String _prefsKey(final String cityId) => 'jazla::$cityId';

  Future<List<Jazla>> load(final String cityId) async {
    final String? raw = await _store.getString(_prefsKey(cityId));
    if (raw == null) return const <Jazla>[];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((final dynamic e) => Jazla.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(final String cityId, final List<Jazla> jazlas) async {
    if (jazlas.isEmpty) {
      await _store.remove(_prefsKey(cityId));
      return;
    }
    await _store.setString(
      _prefsKey(cityId),
      jsonEncode(jazlas.map((final Jazla j) => j.toJson()).toList()),
    );
  }
}
