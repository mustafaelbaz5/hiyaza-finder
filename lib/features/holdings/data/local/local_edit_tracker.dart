import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';

/// Tracks which parcel ids have been edited, beyond what [ParcelEditsStore]
/// stores (which holds the actual edit payloads) — a lightweight id-only
/// index, kept for a future export feature to know which local records
/// have diverged from the original import without decoding every payload.
class LocalEditTracker {
  const LocalEditTracker({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  final KeyValueStore _store;

  static String _key(final String cityId) => 'edited_parcel_ids::$cityId';

  Future<void> markEdited(final String parcelId, final String cityId) async {
    final Set<String> current = await getEditedIds(cityId);
    current.add(parcelId);
    await _store.setString(_key(cityId), jsonEncode(current.toList()));
  }

  Future<Set<String>> getEditedIds(final String cityId) async {
    final String? raw = await _store.getString(_key(cityId));
    if (raw == null) return <String>{};
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<String>().toSet();
  }

  Future<void> clear(final String cityId) async {
    await _store.remove(_key(cityId));
  }
}
