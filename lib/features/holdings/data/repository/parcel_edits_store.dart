import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists user corrections to parcel data, scoped per loaded file so each
/// workbook keeps its own set of edits. The original `.xlsx` is never
/// modified — edits are stored here and overlaid at load time.
///
/// Shape: `{ parcelId: { fieldName: value, ... }, ... }` where each inner
/// map is a full snapshot of the editable fields for that parcel.
class ParcelEditsStore {
  const ParcelEditsStore();

  static String _prefsKey(final String fileKey) => 'parcel_edits::$fileKey';

  Future<Map<String, Map<String, dynamic>>> load(final String fileKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_prefsKey(fileKey));
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (edits.isEmpty) {
      await prefs.remove(_prefsKey(fileKey));
      return;
    }
    await prefs.setString(_prefsKey(fileKey), jsonEncode(edits));
  }
}
