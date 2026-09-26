import 'dart:convert';

import '../storage/key_value_store.dart';

/// Safe JSON access on top of [KeyValueStore].
///
/// It deliberately does not delete malformed values. Returning `null` lets a
/// feature retain the last valid in-memory data and decide whether a
/// migration, recovery message, or a later overwrite is appropriate.
class LocalJsonStore {
  const LocalJsonStore(this._store);

  final KeyValueStore _store;

  Future<Map<String, dynamic>?> readMap(final String key) async {
    final Object? decoded = await _read(key);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<List<dynamic>?> readList(final String key) async {
    final Object? decoded = await _read(key);
    return decoded is List<dynamic> ? decoded : null;
  }

  Future<void> write(final String key, final Object value) =>
      _store.setString(key, jsonEncode(value));

  Future<void> remove(final String key) => _store.remove(key);

  Future<Object?> _read(final String key) async {
    final String? raw = await _store.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
