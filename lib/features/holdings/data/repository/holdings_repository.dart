import 'package:uuid/uuid.dart';

import '../../../cities/domain/entities/city_type.dart';
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
import '../added_holdings_mapper.dart';
import 'parcel_edits_store.dart';

/// Owns the in-memory dataset for the active city, and the local overlay
/// of corrections/additions made to it — search, detail, and the bulk-edit
/// screen all read from here. The Excel-file-picker path this class used
/// to also support was retired in APP_PLAN.md Phase 5; a city download is
/// the only way data gets in now (see `CityPickerCubit.downloadAndActivate`
/// / `loadParcelsForCity`).
class HoldingsRepository implements HoldingsReader, HoldingsWriter {
  HoldingsRepository({
    final ParcelEditsStore editsStore = const ParcelEditsStore(),
    final ParcelQueryService queryService = const ParcelQueryService(),
    final ParcelEditOverlay editOverlay = const ParcelEditOverlay(),
    final BulkEditService bulkEditService = const BulkEditService(),
    this.syncQueue,
    final Uuid uuid = const Uuid(),
  })  : _editsStore = editsStore,
        _queryService = queryService,
        _editOverlay = editOverlay,
        _bulkEditService = bulkEditService,
        _uuid = uuid;

  final ParcelEditsStore _editsStore;
  final ParcelQueryService _queryService;
  final ParcelEditOverlay _editOverlay;
  final BulkEditService _bulkEditService;
  final Uuid _uuid;

  /// `null` until a city has been downloaded/loaded — outbox entries are
  /// only enqueued once a city (and therefore a server to sync to) exists.
  final SyncQueue? syncQueue;
  String? _activeCityId;
  CityType _activeCityType = CityType.unspecified;

  List<Parcel> _parcels = <Parcel>[];

  /// Key under which the active city's local edit overlay is persisted —
  /// `null` until a city has been loaded.
  String? _activeEditsKey;

  /// Original (unedited) parcels by id, so edits can be reset.
  Map<String, Parcel> _originalById = <String, Parcel>{};

  /// Per-parcel edit snapshots for the active city.
  Map<String, Map<String, dynamic>> _edits = <String, Map<String, dynamic>>{};

  /// Ids of parcels added this session via [addLocalParcel] — drives the
  /// "new / pending sync" badge on the detail card. Session-scoped (not
  /// persisted): after an app restart a still-unsynced added record loses
  /// this marker even though it may still be sitting in the outbox.
  final Set<String> _locallyAddedIds = <String>{};

  @override
  List<Parcel> get parcels => _parcels;

  /// Adopts a city-downloaded (or cache-loaded) parcel list as the active
  /// dataset, keyed by [cityId] for local edit persistence. Local edits
  /// made after this call reapply on the next load from cache. [cityType]
  /// is the detection already cached on the `CitySnapshot` — this never
  /// recomputes it from [parcels].
  Future<List<Parcel>> loadParcelsForCity(
    final String cityId,
    final List<Parcel> parcels, {
    final CityType cityType = CityType.unspecified,
  }) async {
    final String key = 'city::$cityId';
    _activeEditsKey = key;
    _activeCityId = cityId;
    _activeCityType = cityType;
    _originalById = <String, Parcel>{
      for (final Parcel p in parcels) p.id: p,
    };
    _edits = await _editsStore.load(key);
    _parcels = parcels.map(_applyEdit).toList();
    return _parcels;
  }

  /// The active city's detected agricultural system — `unspecified` until
  /// a city is loaded or if detection couldn't determine one.
  CityType get activeCityType => _activeCityType;

  /// Whether نوع الائتمان should be hidden everywhere in the UI — true
  /// only for a confirmed الإصلاح الزراعي city. An `unspecified` result
  /// (detection miss) shows the field rather than risk hiding one that
  /// might matter.
  bool get hideCreditType => _activeCityType == CityType.agriculturalReform;

  /// Adds a brand-new record created in the field — either a new person
  /// ([parentHoldingId] `null`) or a new parcel for an existing person
  /// ([parentHoldingId] set to that person's `Parcel.id`). Writes are
  /// local-first: [parcel] is assigned a fresh client id and appended to
  /// the in-memory dataset immediately (so it's searchable/visible right
  /// away, even offline), and an [AddRecordOperation] is enqueued in the
  /// same call — this never waits on the network.
  ///
  /// Does nothing (returns `null`) if no city is active.
  Future<Parcel?> addLocalParcel(
    final Parcel parcel, {
    final String? parentHoldingId,
  }) async {
    final String? cityId = _activeCityId;
    if (cityId == null) return null;

    final Parcel withId = parcel.copyWith(id: _uuid.v4());
    _parcels = <Parcel>[..._parcels, withId];
    _originalById[withId.id] = withId;
    _locallyAddedIds.add(withId.id);

    if (syncQueue != null) {
      await syncQueue!.enqueue(
        AddRecordOperation(
          id: withId.id,
          createdAt: DateTime.now(),
          cityId: cityId,
          parentHoldingId: parentHoldingId,
          record: parcelToAddedHoldingsRecord(withId),
        ),
      );
    }
    return withId;
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
    if (_activeEditsKey != null) {
      await _editsStore.save(_activeEditsKey!, _edits);
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
    if (_activeEditsKey != null) {
      await _editsStore.save(_activeEditsKey!, _edits);
    }
  }

  bool isParcelEdited(final String id) => _edits.containsKey(id);

  /// Whether [id] was added in the field this session and hasn't been
  /// confirmed synced yet — drives the "new / pending sync" badge.
  bool isNewLocalRecord(final String id) => _locallyAddedIds.contains(id);

  /// Searches within [basin] (اسم الحوض) if given, otherwise the whole
  /// dataset — narrowing the scope keeps matching fast on large cities.
  @override
  List<SearchResult> search(final String query, {final String? basin}) =>
      _queryService.search(_parcels, query, basin: basin);

  /// Distinct اسم الحوض values in the active dataset, sorted.
  @override
  List<String> get availableBasins => _queryService.availableBasins(_parcels);

  /// Distinct-holding count per اسم الحوض — how many holdings sit in each
  /// basin, shown beside the basin filter/status views.
  @override
  Map<String, int> get basinHoldingCounts => _queryService.basinHoldingCounts(_parcels);

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
      if (_activeEditsKey != null) {
        await _editsStore.save(_activeEditsKey!, _edits);
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
