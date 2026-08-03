import 'dart:async';

import 'package:get_it/get_it.dart' show GetIt;
import 'package:uuid/uuid.dart';

import '../../../cities/domain/entities/association_type.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/repositories/sync_queue.dart';
import '../../../sync/data/realtime_sync_service.dart';
import '../../../sync/presentation/cubit/sync_status_cubit.dart';
import '../../domain/entities/bulk_editable_field.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/repositories/holdings_reader.dart';
import '../../domain/repositories/holdings_writer.dart';
import '../../domain/services/border_name_index.dart';
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
    this.realtimeSyncService,
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

  /// `null` in tests that construct this repository directly without a
  /// Realtime service — [loadParcelsForCity] simply skips the subscribe
  /// call in that case, same "optional dependency, no-op if absent"
  /// pattern as [syncQueue].
  final RealtimeSyncService? realtimeSyncService;
  String? _activeCityId;
  AssociationType? _activeAssociationType;
  String? _activeAssociationSubtype;

  List<Parcel> _parcels = <Parcel>[];

  /// Precomputed حائز/مالك name → holding lookup for الحدود navigation —
  /// rebuilt (see [_rebuildBorderIndex]) every time [_parcels] changes so
  /// [findByBorderText] never scans the dataset itself. See
  /// [BorderNameIndex] for why this exists and how ambiguous names resolve.
  BorderNameIndex _borderIndex = BorderNameIndex.empty();

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

  /// Fires whenever [_parcels] changes for a reason the currently-visible
  /// UI wouldn't otherwise notice on its own — specifically, a Supabase
  /// Realtime event applied via [applyRemoteChange]. Every local write in
  /// this class already updates its own caller's state directly (e.g.
  /// `updateParcel`'s caller sets its own `_parcels[idx]`), so this stream
  /// only needs to exist for changes that originate *outside* any specific
  /// screen's direct call. Mirrors `SyncQueue.pendingCountChanges`
  /// (`sync_outbox_impl.dart`) — same "a repository-level event, several
  /// possibly-nonexistent listeners" shape, since `HomeCubit` isn't a
  /// singleton and may not even be alive when a remote change arrives.
  final StreamController<void> _remoteChangesController =
      StreamController<void>.broadcast();

  Stream<void> get onRemoteChange => _remoteChangesController.stream;

  @override
  List<Parcel> get parcels => _parcels;

  /// Adopts a city-downloaded (or cache-loaded) parcel list as the active
  /// dataset, keyed by [cityId] for local edit persistence. Local edits
  /// made after this call reapply on the next load from cache.
  /// [associationType]/[associationSubtype] come straight from the
  /// `CitySnapshot` (itself read from `cities.association_type`/
  /// `association_subtype`) — never re-derived from [parcels].
  Future<List<Parcel>> loadParcelsForCity(
    final String cityId,
    final List<Parcel> parcels, {
    final AssociationType? associationType,
    final String? associationSubtype,
  }) async {
    final String key = 'city::$cityId';
    _activeEditsKey = key;
    _activeCityId = cityId;
    _activeAssociationType = associationType;
    _activeAssociationSubtype = associationSubtype;
    _originalById = <String, Parcel>{
      for (final Parcel p in parcels) p.id: p,
    };
    _edits = await _editsStore.load(key);
    _parcels = parcels.map(_applyEdit).toList();
    _rebuildBorderIndex();
    // Realtime tracks exactly one active city, same as this repository —
    // re-subscribing here (rather than at the CityPickerCubit call site)
    // means it also fires for a cache-loaded city at app start, not just a
    // fresh download.
    realtimeSyncService?.subscribeToCity(cityId);
    return _parcels;
  }

  /// Rebuilds [_borderIndex] from the current [_parcels] — called any time
  /// [_parcels] is reassigned (city load, add/edit/bulk-edit) so الحدود
  /// navigation always reflects the latest حائز/مالك names without ever
  /// scanning the dataset at lookup time. O(n) like the reassignment itself
  /// it accompanies, so it adds no new order-of-growth cost to those calls.
  void _rebuildBorderIndex() {
    _borderIndex = BorderNameIndex.build(_parcels);
  }

  /// The active city's جمعية system, read from `cities.association_type` —
  /// `null` until a city is loaded or if the dashboard hasn't set it yet.
  AssociationType? get activeAssociationType => _activeAssociationType;

  /// The active city's free-text association_subtype (e.g. ملك/أوقاف or one
  /// of the three إصلاح variants) — `null` until a city is loaded or if
  /// unset in the database.
  String? get activeAssociationSubtype => _activeAssociationSubtype;

  /// Whether نوع الائتمان should be hidden everywhere in the UI — true only
  /// for a confirmed الإصلاح الزراعي city. `null` (type not set in the DB
  /// yet) shows the field rather than risk hiding one that might matter —
  /// same "never hide on an unknown" philosophy the old detection-miss
  /// fallback used.
  bool get hideCreditType =>
      _activeAssociationType == AssociationType.agriculturalReform;

  /// The default association name (اسم الجمعية) from the active city's
  /// dataset — used to auto-populate this field for new records so they're
  /// consistent. Returns the first non-empty association name found, or
  /// `null` if none exist in the active dataset.
  String? get defaultAssociationName {
    for (final Parcel p in _parcels) {
      if (p.associationName?.trim().isNotEmpty ?? false) {
        return p.associationName;
      }
    }
    return null;
  }

  /// Triggers a synchronization of pending operations.
  /// Used by the RefreshIndicator on the detail screen — same action as the
  /// "مزامنة الآن" button, but called via pull-to-refresh gesture. Delegates
  /// to [SyncStatusCubit.flushNow] rather than resolving [SyncRunner]
  /// directly, so this is not a second, independent "is a sync in flight"
  /// guard — every trigger in the app (manual, connectivity-regained,
  /// app-resume, app-start, login, city-selected) shares the one guard
  /// already on that cubit.
  Future<void> syncNow() => GetIt.instance<SyncStatusCubit>().flushNow();

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

    final Parcel? parent = parentHoldingId == null
        ? null
        : _parcels.cast<Parcel?>().firstWhere(
            (final Parcel? p) => p?.id == parentHoldingId,
            orElse: () => null);

    // A sibling parcel added under a still-pending person (no real رقم
    // الحيازة yet) must join the *same* pending group as its parent —
    // otherwise Parcel.groupKey (keyed on each parcel's own id while
    // pending) would treat it as an unrelated new person. Not needed once
    // the parent has a real holdingId: groupKey already equals holdingId
    // for both in that case.
    final String? pendingGroupId = (parent != null && parent.isHoldingIdPending)
        ? (parent.pendingGroupId ?? parent.id)
        : null;

    final Parcel withId = parcel.copyWith(
      id: _uuid.v4(),
      pendingGroupId: pendingGroupId,
    );

    // Keep عدد القطع في الحيازة consistent across every parcel that shares
    // this holding — the new parcel's count already reflects the total
    // (set by the caller), so every sibling parcel is bumped to match it.
    if (parent != null) {
      _parcels = <Parcel>[
        for (final Parcel p in _parcels)
          if (p.groupKey == parent.groupKey)
            p.copyWith(holdingsCount: withId.holdingsCount)
          else
            p,
      ];
    }

    _parcels = <Parcel>[..._parcels, withId];
    _originalById[withId.id] = withId;
    _locallyAddedIds.add(withId.id);
    _rebuildBorderIndex();

    if (syncQueue != null) {
      // `added_holdings.parent_holding_id` is a foreign key into the
      // canonical `holdings` table, not into `added_holdings` — it's only
      // ever valid once a record has been reviewed/promoted server-side. A
      // parcel added this session (tracked in `_locallyAddedIds`) has a
      // client-generated id that has never been written to `holdings` and
      // never will be until promotion, so sending it as `parent_holding_id`
      // is rejected with a permanent FK violation (the op then retries
      // forever, and the parcel never actually reaches the server). Send
      // `null` instead — same as a brand-new person with no known parent.
      final String? safeParentHoldingId =
          (parentHoldingId != null && _locallyAddedIds.contains(parentHoldingId))
              ? null
              : parentHoldingId;
      await syncQueue!.enqueue(
        AddRecordOperation(
          id: withId.id,
          createdAt: DateTime.now(),
          cityId: cityId,
          parentHoldingId: safeParentHoldingId,
          record: parcelToAddedHoldingsRecord(withId),
        ),
      );
    }
    return withId;
  }

  /// Whether [id] can be deleted via [deleteLocalParcel] — only records
  /// created in the field ([addLocalParcel]) that haven't synced to the
  /// server yet. Once a field-added record reaches `added_holdings` it
  /// enters the dashboard's pending/approved/rejected review workflow —
  /// there is no client-side delete for it beyond this point (staff review
  /// it instead; see APP_PLAN.md § "added_holdings"). Checks the live
  /// outbox — not [_locallyAddedIds], which is session-scoped and would
  /// wrongly say "no" for a still-unsynced record after an app restart.
  Future<bool> canDeleteLocalParcel(final String id) async {
    final SyncQueue? queue = syncQueue;
    if (queue == null) return false;
    final List<SyncOperation> pending = await queue.pending();
    return pending.any(
      (final SyncOperation op) => op is AddRecordOperation && op.id == id,
    );
  }

  /// Deletes a still-unsynced field-added record — removes its queued
  /// [AddRecordOperation] (so it's never pushed to the server at all) and
  /// drops it from the in-memory dataset. Does nothing and returns `false`
  /// if [id] isn't eligible (see [canDeleteLocalParcel]): already synced,
  /// or was never a locally-added record to begin with (e.g. part of the
  /// authoritative `holdings` import, which this app never deletes).
  Future<bool> deleteLocalParcel(final String id) async {
    if (!await canDeleteLocalParcel(id)) return false;

    final int idx = _parcels.indexWhere((final Parcel p) => p.id == id);
    if (idx < 0) return false;
    final Parcel removed = _parcels[idx];

    await syncQueue!.remove(id);

    _parcels = <Parcel>[
      for (final Parcel p in _parcels)
        if (p.id != id)
          // Mirrors addLocalParcel's bump: undo it for any sibling parcel
          // still sharing this holding.
          (p.groupKey == removed.groupKey && p.holdingsCount != null)
              ? p.copyWith(holdingsCount: p.holdingsCount! - 1)
              : p,
    ];
    _originalById.remove(id);
    _locallyAddedIds.remove(id);
    _edits.remove(id);
    if (_activeEditsKey != null) {
      await _editsStore.save(_activeEditsKey!, _edits);
    }
    _rebuildBorderIndex();
    return true;
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
    // A single-field edit can change حائز/مالك name — rebuild so a fresh
    // الحدود lookup elsewhere in the city sees the update immediately.
    _rebuildBorderIndex();
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

  /// Patches a single parcel arriving from a Supabase Realtime `holdings`/
  /// `added_holdings` INSERT or UPDATE event (already mapped to a [Parcel]
  /// by `holdingRowToParcel`/`addedHoldingRowToParcel` — this method does no
  /// parsing of its own). Replaces the parcel by id if it already exists in
  /// [_parcels], or appends it if this is the first this device has seen of
  /// it (e.g. another device just added it). [_originalById] is always
  /// updated to the new server-confirmed value, since it represents "what
  /// the server has" for [resetParcel] purposes regardless of what's shown.
  ///
  /// Does nothing if no city is active or [updated] belongs to a different
  /// city than the one currently loaded — a stray event from a
  /// slow-to-unsubscribe previous city's channel should never mutate the
  /// dataset the user is currently looking at.
  void applyRemoteChange(final Parcel updated) {
    if (_activeCityId == null) return;

    _originalById[updated.id] = updated;
    final Parcel toShow = _applyEdit(updated);
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == updated.id);
    if (idx >= 0) {
      _parcels[idx] = toShow;
    } else {
      _parcels = <Parcel>[..._parcels, toShow];
    }
    _rebuildBorderIndex();
    _remoteChangesController.add(null);
  }

  /// Merges a `holding_edits` INSERT event's payload (a `toEditableJson`-
  /// shaped map, same as [ParcelEditOverlay.snapshot] produces) onto the
  /// parcel's current original value. Skipped entirely if this device has
  /// its own unsynced local edit for [holdingId] (`_edits.containsKey`) —
  /// the offline-first guarantee is that a local write stays authoritative
  /// on-screen until it has synced, so a remote correction arriving in the
  /// meantime must not clobber it.
  void applyRemoteEdit(final String holdingId, final Map<String, dynamic> payload) {
    if (_activeCityId == null) return;
    if (_edits.containsKey(holdingId)) return;

    final Parcel? original = _originalById[holdingId];
    if (original == null) return;

    final Parcel merged = _editOverlay.apply(original, payload);
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == holdingId);
    if (idx < 0) return;
    _parcels[idx] = merged;
    _rebuildBorderIndex();
    _remoteChangesController.add(null);
  }

  /// Removes a parcel from the active dataset in response to a Supabase
  /// Realtime DELETE event — a holding marked stale, or an `added_holdings`
  /// row rejected/deleted server-side. No-op if [id] isn't in the active
  /// dataset (e.g. a stray event for a different city).
  void applyRemoteDelete(final String id) {
    if (_activeCityId == null) return;
    final int before = _parcels.length;
    _parcels = <Parcel>[
      for (final Parcel p in _parcels)
        if (p.id != id) p,
    ];
    if (_parcels.length == before) return;
    _originalById.remove(id);
    _rebuildBorderIndex();
    _remoteChangesController.add(null);
  }

  bool isParcelEdited(final String id) => _edits.containsKey(id);

  /// The pre-edit value of the parcel [id] — either the originally
  /// downloaded row, or (for a field-added record) the value at the moment
  /// it was created. `null` if [id] isn't in the active dataset. Used to
  /// drive per-field "معدلة" indicators by comparing each field against
  /// its own original value, rather than only knowing *that* something on
  /// the parcel changed (see `isParcelEdited`).
  Parcel? originalParcel(final String id) => _originalById[id];

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
  Map<String, int> get basinHoldingCounts =>
      _queryService.basinHoldingCounts(_parcels);

  @override
  List<Parcel> parcelsForHolding(final String holdingId) =>
      _queryService.parcelsForHolding(_parcels, holdingId);

  @override
  Parcel? findByBorderText(final String? borderText) =>
      _queryService.findByBorderText(_borderIndex, borderText);

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
    // Defensive: no `BulkEditableField` touches حائز/مالك today, but
    // rebuilding here is O(n) same as the reassignment above and keeps
    // this repository from silently drifting out of sync if that ever
    // changes, without needing every future field to remember this rule.
    _rebuildBorderIndex();
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
