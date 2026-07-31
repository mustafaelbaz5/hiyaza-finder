import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';

/// Persists user corrections to parcel data, scoped per loaded file so each
/// workbook keeps its own set of edits. The original `.xlsx` is never
/// modified — edits are stored here and overlaid at load time.
///
/// Shape: `{ parcelId: { fieldName: value, ... }, ... }` where each inner
/// map is a full snapshot of the editable fields for that parcel.
class ParcelEditsStore {
  const ParcelEditsStore({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  final KeyValueStore _store;

  static String _prefsKey(final String fileKey) => 'parcel_edits::$fileKey';

  Future<Map<String, Map<String, dynamic>>> load(final String fileKey) async {
    final String? raw = await _store.getString(_prefsKey(fileKey));
    if (raw == null || raw.isEmpty) return <String, Map<String, dynamic>>{};

    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (final String id, final dynamic fields) =>
          MapEntry<String, Map<String, dynamic>>(
        id,
        (fields as Map<String, dynamic>),
      ),
    );
  }

  Future<void> save(
    final String fileKey,
    final Map<String, Map<String, dynamic>> edits,
  ) async {
    if (edits.isEmpty) {
      await _store.remove(_prefsKey(fileKey));
      return;
    }
    await _store.setString(_prefsKey(fileKey), jsonEncode(edits));
  }
}
