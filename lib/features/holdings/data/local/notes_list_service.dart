import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';
import '../model/parcel.dart';

/// Persists the user's custom additions to the ملاحظات quick-pick list
/// (APP_UPDATES_CLAUDE.md § 5.2) — layered on top of [Parcel.notesOptions]'s
/// fixed built-in list, never replacing it. Editable from City Tools
/// Settings; doesn't affect notes already saved on a parcel.
class NotesListService {
  const NotesListService(this._store);

  final KeyValueStore _store;

  static const String _key = 'custom_notes_list';

  /// The fixed built-in list plus the user's saved custom notes, with
  /// duplicates removed and غير `Parcel.notesOtherOption` (which stays a
  /// sentinel, not a pickable note).
  Future<List<String>> getUserNotesList() async {
    final List<String> custom = await _readCustom();
    final List<String> builtIn = Parcel.notesOptions
        .where((final String n) => n != Parcel.notesOtherOption)
        .toList();
    return <String>{...builtIn, ...custom}.toList();
  }

  Future<List<String>> getCustomNotes() => _readCustom();

  Future<void> addNote(final String note) async {
    final String trimmed = note.trim();
    if (trimmed.isEmpty) return;
    final List<String> custom = await _readCustom();
    if (custom.contains(trimmed)) return;
    await _writeCustom(<String>[...custom, trimmed]);
  }

  Future<void> removeNote(final String note) async {
    final List<String> custom = await _readCustom();
    await _writeCustom(custom.where((final String n) => n != note).toList());
  }

  Future<List<String>> _readCustom() async {
    final String? raw = await _store.getString(_key);
    if (raw == null || raw.isEmpty) return const <String>[];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<String>();
  }

  Future<void> _writeCustom(final List<String> notes) =>
      _store.setString(_key, jsonEncode(notes));
}
