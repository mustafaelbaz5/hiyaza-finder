import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../logic/services/holding_search_service.dart';
import '../excel/holdings_excel_parser.dart';
import '../models/bulk_editable_field.dart';
import '../models/cached_file_entry.dart';
import '../models/parcel.dart';
import 'parcel_edits_store.dart';

/// Runs the (potentially heavy) Excel parse in a background isolate via
/// [compute] so the UI thread never freezes while reading a large workbook.
/// Must be a top-level function — [compute] cannot capture closures.
List<Parcel> _parseHoldingsBytes(final Uint8List bytes) =>
    const HoldingsExcelParser().parse(bytes);

/// Owns the in-memory dataset and the on-device cache of picked workbooks,
/// so the app can reload any of them offline without re-prompting the file
/// picker (SAF/URI permissions on the original pick can expire, so each
/// file is copied into app storage instead of just remembering its path).
///
/// Keeps a small history of every distinct file that has been loaded, so
/// the user can switch back to a previous one from the History screen.
class HoldingsRepository {
  HoldingsRepository({
    final HoldingSearchService searchService = const HoldingSearchService(),
    final ParcelEditsStore editsStore = const ParcelEditsStore(),
  }) : _searchService = searchService,
       _editsStore = editsStore;

  static const String _activeFilePathKey = 'holdings_active_file_path';
  static const String _historyKey = 'holdings_file_history';
  static const String _cacheDirName = 'holdings_cache';
  static const int _maxHistoryEntries = 15;

  static String _associationNameKey(final String filePath) =>
      'association_name::$filePath';

  final HoldingSearchService _searchService;
  final ParcelEditsStore _editsStore;

  List<Parcel> _parcels = <Parcel>[];

  /// Path of the file whose edits are currently loaded — the key under
  /// which corrections are persisted.
  String? _activeFilePath;

  /// Whether the active file's اسم الجمعية has already been confirmed by
  /// the user (either just now, or on a previous load of the same file).
  bool _associationNameConfirmed = false;

  bool get associationNameNeedsConfirmation => !_associationNameConfirmed;

  String? get activeAssociationName =>
      _parcels.isNotEmpty ? _parcels.first.associationName : null;

  /// Derives a default اسم الجمعية from a workbook file name, e.g.
  /// `"شنشا_كامل.xlsx"` → `"شنشا"`, `"منشاه_الاخوه_كامل.xlsx"` →
  /// `"منشاه الاخوه"`. Strips the extension and a trailing "كامل" segment.
  static String deriveAssociationName(final String fileName) {
    String name = fileName;
    final int dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);

    final List<String> parts = name
        .split('_')
        .map((final String s) => s.trim())
        .where((final String s) => s.isNotEmpty)
        .toList();
    if (parts.isNotEmpty && parts.last == 'كامل') {
      parts.removeLast();
    }
    return parts.join(' ').trim();
  }

  /// Original (unedited) parcels by id, so edits can be reset.
  Map<String, Parcel> _originalById = <String, Parcel>{};

  /// Per-parcel edit snapshots for the active file.
  Map<String, Map<String, dynamic>> _edits = <String, Map<String, dynamic>>{};

  List<Parcel> get parcels => _parcels;

  /// Picks a `.xlsx` file, copies it into app storage under a unique name,
  /// records it in the file history, parses it (off the UI thread), and
  /// makes it the active dataset.
  Future<List<Parcel>> loadFromPickedFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['xlsx'],
      withData: true,
    );
    final PlatformFile? picked = result?.files.single;
    if (picked == null) {
      throw const HoldingsFilePickCancelled();
    }

    final Uint8List bytes =
        picked.bytes ?? await File(picked.path!).readAsBytes();
    final List<Parcel> parsed = await compute(_parseHoldingsBytes, bytes);

    final String fileName = picked.name;
    final String cachedPath = await _cacheBytes(bytes, fileName);
    await _rememberInHistory(
      CachedFileEntry(
        fileName: fileName,
        filePath: cachedPath,
        cachedAt: DateTime.now(),
        holdingCount: parsed.map((final Parcel p) => p.holdingId).toSet().length,
      ),
    );
    await _setActivePath(cachedPath);

    return _finalizeLoad(parsed, cachedPath, fileName);
  }

  /// Loads the previously active file, if any. Returns `null` when nothing
  /// has been cached yet (caller should show the Empty state).
  Future<List<Parcel>?> loadCachedFileIfAny() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? path = prefs.getString(_activeFilePathKey);
    if (path == null) return null;
    return _loadFromPath(path);
  }

  /// Switches the active dataset to a previously-loaded file from history.
  Future<List<Parcel>> loadFromHistoryEntry(
    final CachedFileEntry entry,
  ) async {
    final List<Parcel>? parsed = await _loadFromPath(entry.filePath);
    if (parsed == null) {
      throw const HoldingsFilePickCancelled();
    }
    await _setActivePath(entry.filePath);
    return parsed;
  }

  Future<List<Parcel>?> _loadFromPath(final String path) async {
    final File file = File(path);
    if (!file.existsSync()) return null;

    final Uint8List bytes = await file.readAsBytes();
    final List<Parcel> parsed = await compute(_parseHoldingsBytes, bytes);
    final String fileName = await _fileNameForPath(path);
    return _finalizeLoad(parsed, path, fileName);
  }

  /// Looks up the original picked file name for a cached [path] from the
  /// file history, falling back to the cache file's own basename.
  Future<String> _fileNameForPath(final String path) async {
    final List<CachedFileEntry> history = await getHistory();
    for (final CachedFileEntry entry in history) {
      if (entry.filePath == path) return entry.fileName;
    }
    return path.split(Platform.pathSeparator).last;
  }

  /// Assigns stable ids, resolves اسم الجمعية (a saved override, or derived
  /// from [fileName]), remembers the originals, and overlays any saved
  /// edits for [filePath] before exposing the dataset.
  Future<List<Parcel>> _finalizeLoad(
    final List<Parcel> parsed,
    final String filePath,
    final String fileName,
  ) async {
    _activeFilePath = filePath;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? override = prefs.getString(_associationNameKey(filePath));
    _associationNameConfirmed = override != null;
    final String associationName =
        override ?? deriveAssociationName(fileName);

    final List<Parcel> withIds = <Parcel>[
      for (var i = 0; i < parsed.length; i++)
        parsed[i].copyWith(id: i.toString(), associationName: associationName),
    ];
    _originalById = <String, Parcel>{
      for (final Parcel p in withIds) p.id: p,
    };
    _edits = await _editsStore.load(filePath);
    _parcels = withIds.map(_applyEdit).toList();
    return _parcels;
  }

  /// Confirms (or corrects) the active file's اسم الجمعية, persists it so
  /// this file won't need re-confirming next time it's loaded, and stamps
  /// it onto every currently-loaded parcel.
  Future<void> confirmAssociationName(final String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (_activeFilePath != null) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_associationNameKey(_activeFilePath!), trimmed);
    }
    _associationNameConfirmed = true;
    _parcels = <Parcel>[
      for (final Parcel p in _parcels) p.copyWith(associationName: trimmed),
    ];
    _originalById = <String, Parcel>{
      for (final MapEntry<String, Parcel> e in _originalById.entries)
        e.key: e.value.copyWith(associationName: trimmed),
    };
  }

  Parcel _applyEdit(final Parcel p) {
    final Map<String, dynamic>? e = _edits[p.id];
    if (e == null) return p;
    return Parcel.fromEditableJson(p, e);
  }

  Map<String, dynamic> _snapshot(final Parcel p) => p.toEditableJson();

  /// Persists an edited parcel and reflects it in the in-memory dataset so
  /// search, detail, and border navigation immediately use the new values.
  Future<void> updateParcel(final Parcel edited) async {
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == edited.id);
    if (idx < 0) return;
    _parcels[idx] = edited;
    _edits[edited.id] = _snapshot(edited);
    if (_activeFilePath != null) {
      await _editsStore.save(_activeFilePath!, _edits);
    }
  }

  /// Reverts a parcel to its original parsed values.
  Future<void> resetParcel(final String id) async {
    final Parcel? original = _originalById[id];
    if (original == null) return;
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == id);
    if (idx >= 0) _parcels[idx] = original;
    _edits.remove(id);
    if (_activeFilePath != null) {
      await _editsStore.save(_activeFilePath!, _edits);
    }
  }

  bool isParcelEdited(final String id) => _edits.containsKey(id);

  Future<String> _cacheBytes(
    final Uint8List bytes,
    final String originalFileName,
  ) async {
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final Directory cacheDir = Directory(
      '${docsDir.path}/$_cacheDirName',
    );
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    final String safeName = originalFileName.replaceAll(
      RegExp(r'[^\w.\-؀-ۿ]'),
      '_',
    );
    final String uniqueName =
        '${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final File cached = File('${cacheDir.path}/$uniqueName');
    await cached.writeAsBytes(bytes, flush: true);
    return cached.path;
  }

  Future<void> _setActivePath(final String path) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeFilePathKey, path);
  }

  Future<void> _rememberInHistory(final CachedFileEntry entry) async {
    final List<CachedFileEntry> history = await getHistory();

    // Replace any earlier entry for the same file name so re-picking the
    // same workbook doesn't accumulate duplicate cached copies.
    CachedFileEntry? previous;
    for (final CachedFileEntry e in history) {
      if (e.fileName == entry.fileName) {
        previous = e;
        break;
      }
    }
    if (previous != null) {
      history.remove(previous);
      final File oldFile = File(previous.filePath);
      if (oldFile.existsSync() && previous.filePath != entry.filePath) {
        await oldFile.delete();
      }
    }

    history.insert(0, entry);
    while (history.length > _maxHistoryEntries) {
      final CachedFileEntry removed = history.removeLast();
      final File removedFile = File(removed.filePath);
      if (removedFile.existsSync()) {
        await removedFile.delete();
      }
    }

    await _saveHistory(history);
  }

  /// All previously loaded files, most recently added first.
  Future<List<CachedFileEntry>> getHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return <CachedFileEntry>[];

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (final dynamic e) =>
              CachedFileEntry.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// Removes a stale history entry (e.g. its cached file was deleted
  /// outside the app) without touching the currently active dataset.
  Future<void> removeHistoryEntry(final CachedFileEntry entry) async {
    final List<CachedFileEntry> history = await getHistory();
    history.removeWhere(
      (final CachedFileEntry e) => e.filePath == entry.filePath,
    );
    await _saveHistory(history);
  }

  Future<void> _saveHistory(final List<CachedFileEntry> history) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      history.map((final CachedFileEntry e) => e.toJson()).toList(),
    );
    await prefs.setString(_historyKey, encoded);
  }

  /// Searches within [basin] (اسم الحوض) if given, otherwise the whole
  /// dataset — narrowing the scope keeps fuzzy matching fast on large files.
  List<SearchResult> search(final String query, {final String? basin}) {
    final List<Parcel> scope = basin == null
        ? _parcels
        : _parcels.where((final Parcel p) => p.basinName == basin).toList();
    return _searchService.search(scope, query);
  }

  /// Distinct اسم الحوض values in the active dataset, sorted.
  List<String> get availableBasins {
    final Set<String> basins = <String>{};
    for (final Parcel p in _parcels) {
      final String? name = p.basinName?.trim();
      if (name != null && name.isNotEmpty) basins.add(name);
    }
    final List<String> sorted = basins.toList()..sort();
    return sorted;
  }

  /// Distinct-holding count per اسم الحوض — how many holdings sit in each
  /// basin, shown beside the basin filter/status views.
  Map<String, int> get basinHoldingCounts {
    final Map<String, Set<String>> holdingsByBasin = <String, Set<String>>{};
    for (final Parcel p in _parcels) {
      final String? name = p.basinName?.trim();
      if (name == null || name.isEmpty) continue;
      holdingsByBasin.putIfAbsent(name, () => <String>{}).add(p.holdingId);
    }
    return <String, int>{
      for (final MapEntry<String, Set<String>> e in holdingsByBasin.entries)
        e.key: e.value.length,
    };
  }

  List<Parcel> parcelsForHolding(final String holdingId) =>
      _parcels.where((final Parcel p) => p.holdingId == holdingId).toList();

  /// Applies [value] to every parcel's [field], optionally scoped to
  /// [basin] (only parcels whose اسم الحوض matches). Returns how many
  /// parcels were changed, for user feedback.
  Future<int> bulkApplyField({
    required final BulkEditableField field,
    required final Object? value,
    final String? basin,
  }) async {
    int changed = 0;
    for (var i = 0; i < _parcels.length; i++) {
      final Parcel p = _parcels[i];
      if (basin != null && p.basinName != basin) continue;

      final Parcel updated = switch (field) {
        BulkEditableField.cropType => p.copyWith(cropType: value as String?),
        BulkEditableField.notes => p.copyWith(notes: value as String?),
        BulkEditableField.creditType =>
          p.copyWith(creditType: value as String),
        BulkEditableField.usageType => p.copyWith(usageType: value as String),
        BulkEditableField.isInheritance =>
          p.copyWith(isInheritance: value as bool),
      };
      _parcels[i] = updated;
      _edits[updated.id] = updated.toEditableJson();
      changed++;
    }
    if (changed > 0 && _activeFilePath != null) {
      await _editsStore.save(_activeFilePath!, _edits);
    }
    return changed;
  }
}

class HoldingsFilePickCancelled implements Exception {
  const HoldingsFilePickCancelled();
}
