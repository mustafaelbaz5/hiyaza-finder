import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/storage/key_value_store.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/repositories/sync_queue.dart';
import '../../domain/entities/bulk_editable_field.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/repositories/holdings_reader.dart';
import '../../domain/repositories/holdings_writer.dart';
import '../../domain/services/bulk_edit_service.dart';
import '../../domain/services/parcel_edit_overlay.dart';
import '../../domain/services/parcel_query_service.dart';
import '../../logic/services/holding_search_service.dart';
import '../excel/holdings_excel_parser.dart';
import '../models/cached_file_entry.dart';
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
class HoldingsRepository implements HoldingsReader, HoldingsWriter {
  HoldingsRepository({
    final ParcelEditsStore editsStore = const ParcelEditsStore(),
    final KeyValueStore keyValueStore = const SharedPreferencesKeyValueStore(),
    final ParcelQueryService queryService = const ParcelQueryService(),
    final ParcelEditOverlay editOverlay = const ParcelEditOverlay(),
    final BulkEditService bulkEditService = const BulkEditService(),
    this.syncQueue,
    final Uuid uuid = const Uuid(),
  })  : _editsStore = editsStore,
        _keyValueStore = keyValueStore,
        _queryService = queryService,
        _editOverlay = editOverlay,
        _bulkEditService = bulkEditService,
        _uuid = uuid;

  static const String _activeFilePathKey = 'holdings_active_file_path';
  static const String _historyKey = 'holdings_file_history';
  static const String _cacheDirName = 'holdings_cache';
  static const int _maxHistoryEntries = 15;

  static String _associationNameKey(final String filePath) =>
      'association_name::$filePath';

  final ParcelEditsStore _editsStore;
  final KeyValueStore _keyValueStore;
  final ParcelQueryService _queryService;
  final ParcelEditOverlay _editOverlay;
  final BulkEditService _bulkEditService;
  final Uuid _uuid;

  /// `null` until a city has been downloaded/loaded — outbox entries are
  /// only enqueued for city-sourced data (Excel-sourced edits have no
  /// server to sync to; that whole flow is retired in APP_PLAN.md Phase 5).
  final SyncQueue? syncQueue;
  String? _activeCityId;

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

  @override
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
        holdingCount:
            parsed.map((final Parcel p) => p.holdingId).toSet().length,
      ),
    );
    await _setActivePath(cachedPath);

    return _finalizeLoad(parsed, cachedPath, fileName);
  }

  /// Loads the previously active file, if any. Returns `null` when nothing
  /// has been cached yet (caller should show the Empty state).
  Future<List<Parcel>?> loadCachedFileIfAny() async {
    final String? path = await _keyValueStore.getString(_activeFilePathKey);
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
    _activeCityId = null;

    final String? override =
        await _keyValueStore.getString(_associationNameKey(filePath));
    _associationNameConfirmed = override != null;
    final String associationName = override ?? deriveAssociationName(fileName);

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

  /// Adopts a city-downloaded (or cache-loaded) parcel list as the active
  /// dataset, keyed by [cityId] for local edit persistence — the same
  /// [ParcelEditsStore] mechanism [loadFromPickedFile] uses to key its
  /// edits, just keyed by city id instead of a file path. Local edits made
  /// after this call reapply on the next load from cache, same as today.
  /// اسم الجمعية never needs confirming here — the server already supplies
  /// the real value per parcel.
  Future<List<Parcel>> loadParcelsForCity(
    final String cityId,
    final List<Parcel> parcels,
  ) async {
    final String key = 'city::$cityId';
    _activeFilePath = key;
    _activeCityId = cityId;
    _associationNameConfirmed = true;
    _originalById = <String, Parcel>{
      for (final Parcel p in parcels) p.id: p,
    };
    _edits = await _editsStore.load(key);
    _parcels = parcels.map(_applyEdit).toList();
    return _parcels;
  }

  /// Confirms (or corrects) the active file's اسم الجمعية, persists it so
  /// this file won't need re-confirming next time it's loaded, and stamps
  /// it onto every currently-loaded parcel.
  Future<void> confirmAssociationName(final String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (_activeFilePath != null) {
      await _keyValueStore.setString(
        _associationNameKey(_activeFilePath!),
        trimmed,
      );
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

  Parcel _applyEdit(final Parcel p) => _editOverlay.apply(p, _edits[p.id]);

  /// Persists an edited parcel and reflects it in the in-memory dataset so
  /// search, detail, and border navigation immediately use the new values.
  /// Writes are local-first: this returns as soon as the local cache is
  /// updated — [syncQueue] enqueueing never waits on the network.
  @override
  Future<void> updateParcel(final Parcel edited) async {
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == edited.id);
    if (idx < 0) return;
    _parcels[idx] = edited;
    final Map<String, dynamic> snapshot = _editOverlay.snapshot(edited);
    _edits[edited.id] = snapshot;
    if (_activeFilePath != null) {
      await _editsStore.save(_activeFilePath!, _edits);
    }

    final String? cityId = _activeCityId;
    if (cityId != null && syncQueue != null) {
      await syncQueue!.enqueue(
        EditHoldingOperation(
          id: _uuid.v4(),
          createdAt: DateTime.now(),
          cityId: cityId,
          holdingId: edited.id,
          payload: snapshot,
        ),
      );
    }
  }

  /// Reverts a parcel to its original parsed values.
  @override
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
    await _keyValueStore.setString(_activeFilePathKey, path);
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
    final String? raw = await _keyValueStore.getString(_historyKey);
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
    final String encoded = jsonEncode(
      history.map((final CachedFileEntry e) => e.toJson()).toList(),
    );
    await _keyValueStore.setString(_historyKey, encoded);
  }

  /// Searches within [basin] (اسم الحوض) if given, otherwise the whole
  /// dataset — narrowing the scope keeps matching fast on large files.
  @override
  List<SearchResult> search(final String query, {final String? basin}) =>
      _queryService.search(_parcels, query, basin: basin);

  /// Distinct اسم الحوض values in the active dataset, sorted.
  @override
  List<String> get availableBasins => _queryService.availableBasins(_parcels);

  /// Distinct-holding count per اسم الحوض — how many holdings sit in each
  /// basin, shown beside the basin filter/status views.
  @override
  Map<String, int> get basinHoldingCounts =>
      _queryService.basinHoldingCounts(_parcels);

  @override
  List<Parcel> parcelsForHolding(final String holdingId) =>
      _queryService.parcelsForHolding(_parcels, holdingId);

  /// Applies [value] to every parcel's [field], optionally scoped to
  /// [basin] (only parcels whose اسم الحوض matches). Returns how many
  /// parcels were changed, for user feedback.
  @override
  Future<int> bulkApplyField({
    required final BulkEditableField field,
    required final Object? value,
    final String? basin,
  }) async {
    final BulkEditResult result = _bulkEditService.apply(
      _parcels,
      field: field,
      value: value,
      basin: basin,
    );
    _parcels = result.parcels;
    if (result.changedCount > 0) {
      final List<BulkEditRow> syncRows = <BulkEditRow>[];
      for (final Parcel p in _parcels) {
        if (basin == null || p.basinName == basin) {
          final Map<String, dynamic> snapshot = _editOverlay.snapshot(p);
          _edits[p.id] = snapshot;
          syncRows.add(
            BulkEditRow(holdingId: p.id, opId: _uuid.v4(), payload: snapshot),
          );
        }
      }
      if (_activeFilePath != null) {
        await _editsStore.save(_activeFilePath!, _edits);
      }

      final String? cityId = _activeCityId;
      if (cityId != null && syncQueue != null) {
        await syncQueue!.enqueue(
          BulkEditOperation(
            id: _uuid.v4(),
            createdAt: DateTime.now(),
            cityId: cityId,
            rows: syncRows,
          ),
        );
      }
    }
    return result.changedCount;
  }
}

class HoldingsFilePickCancelled implements Exception {
  const HoldingsFilePickCancelled();
}
