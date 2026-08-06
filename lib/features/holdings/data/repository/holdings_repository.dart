import 'dart:async';

import 'package:get_it/get_it.dart' show GetIt;
import 'package:uuid/uuid.dart';

import '../../../cities/domain/entities/association_type.dart';
import '../../../cities/domain/entities/city.dart';
import '../../../cities/domain/repositories/city_repository.dart';
import '../../../sync/data/holdings_api.dart';
import '../../../sync/data/realtime_sync_service.dart';
import '../../../sync/domain/parcel_change_handler.dart';
import '../../domain/entities/bulk_edit_outcome.dart';
import '../../domain/entities/bulk_editable_field.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/repositories/holdings_reader.dart';
import '../../domain/repositories/holdings_writer.dart';
import '../../domain/services/border_name_index.dart';
import '../../domain/services/bulk_edit_service.dart';
import '../../domain/services/parcel_edit_overlay.dart';
import '../../domain/services/parcel_query_service.dart';
import '../../logic/services/holding_search_service.dart';
import '../services/parcel_sync_service.dart';
import 'parcel_edits_store.dart';

/// Owns the in-memory dataset for the active city, and the local overlay
/// of corrections/additions made to it — search, detail, and the bulk-edit
/// screen all read from here. The Excel-file-picker path this class used
/// to also support was retired in APP_PLAN.md Phase 5; a city download is
/// the only way data gets in now (see `CityPickerCubit.downloadAndActivate`
/// / `loadParcelsForCity`).
///
/// Every write method (`addLocalParcel`, `deleteLocalParcel`, `updateParcel`,
/// `setParcelReviewed`, `bulkApplyField`) awaits the Supabase call FIRST and
/// only mutates [_parcels]/[_edits] once the server has confirmed the
/// write — there is no local-first deferral/outbox: a failed write throws
/// and leaves the in-memory dataset exactly as it was, for the caller to
/// catch and show an error.
class HoldingsRepository
    implements HoldingsReader, HoldingsWriter, ParcelChangeHandler {
  HoldingsRepository({
    final ParcelEditsStore editsStore = const ParcelEditsStore(),
    final ParcelQueryService queryService = const ParcelQueryService(),
    final ParcelEditOverlay editOverlay = const ParcelEditOverlay(),
    final BulkEditService bulkEditService = const BulkEditService(),
    this.holdingsApi,
    this.realtimeSyncService,
    final Uuid uuid = const Uuid(),
    final ParcelSyncService? syncService,
  })  : _editsStore = editsStore,
        _queryService = queryService,
        _editOverlay = editOverlay,
        _bulkEditService = bulkEditService,
        _uuid = uuid,
        _syncService = syncService ?? ParcelSyncService(holdingsApi: holdingsApi);

  final ParcelEditsStore _editsStore;
  final ParcelQueryService _queryService;
  final ParcelEditOverlay _editOverlay;
  final BulkEditService _bulkEditService;
  final Uuid _uuid;
  final ParcelSyncService _syncService;

  /// `null` in tests that construct this repository directly without a
  /// Supabase-backed API — every write method treats a `null` [holdingsApi]
  /// as a no-op network call (mutates local state as if the write
  /// succeeded), which is what lets the existing add/delete/reviewed tests
  /// construct a repository with no network dependency at all.
  final HoldingsApi? holdingsApi;

  /// `null` in tests that construct this repository directly without a
  /// Realtime service — [loadParcelsForCity] simply skips the subscribe
  /// call in that case, same "optional dependency, no-op if absent"
  /// pattern as [holdingsApi].
  final RealtimeSyncService? realtimeSyncService;
  String? _activeCityId;
  String? _activeCityName;
  String? _activeDirectorate;
  String? _activeAdministration;
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

  /// Per-parcel edit snapshots for the active city — unrelated to the write
  /// strategy above, this is the overlay [resetParcel] reverts against and
  /// that reapplies corrections on top of freshly-loaded server rows.
  Map<String, Map<String, dynamic>> _edits = <String, Map<String, dynamic>>{};

  /// Fires whenever [_parcels] changes for a reason the currently-visible
  /// UI wouldn't otherwise notice on its own — specifically, a Supabase
  /// Realtime event applied via [applyRemoteChange]. Every local write in
  /// this class already updates its own caller's state directly (e.g.
  /// `updateParcel`'s caller sets its own `_parcels[idx]`), so this stream
  /// only needs to exist for changes that originate *outside* any specific
  /// screen's direct call, since `HomeCubit` isn't a singleton and may not
  /// even be alive when a remote change arrives.
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
    final String? cityName,
    final String? directorate,
    final String? administration,
    final AssociationType? associationType,
    final String? associationSubtype,
  }) async {
    final String key = 'city::$cityId';
    _activeEditsKey = key;
    _activeCityId = cityId;
    _activeCityName = cityName ?? _activeCityName;
    _activeDirectorate = directorate ?? _activeDirectorate;
    _activeAdministration = administration ?? _activeAdministration;
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

  /// Re-downloads the active city and adopts the fresh data — the detail
  /// screen's pull-to-refresh. Under online-first there is no pending-write
  /// queue to flush; this simply re-syncs the local cache with the server,
  /// same "re-fetch, then adopt" shape as `HomeCubit.refreshActiveCity`.
  /// No-op if no city is active.
  Future<void> syncNow() async {
    final String? cityId = _activeCityId;
    final String? cityName = _activeCityName;
    if (cityId == null || cityName == null) return;

    final CityRepository cityRepository = GetIt.instance<CityRepository>();
    final int remoteVersion = await cityRepository.remoteDataVersion(cityId);
    final City city = City(
      id: cityId,
      name: cityName,
      status: CityStatus.published,
      dataVersion: remoteVersion,
      directorate: _activeDirectorate,
      administration: _activeAdministration,
      associationType: _activeAssociationType,
      associationSubtype: _activeAssociationSubtype,
    );
    final fresh = await cityRepository.downloadCity(city);
    await loadParcelsForCity(
      fresh.cityId,
      fresh.parcels,
      cityName: fresh.cityName,
      directorate: fresh.directorate,
      administration: fresh.administration,
      associationType: fresh.associationType,
      associationSubtype: fresh.associationSubtype,
    );
  }

  /// Adds a brand-new record created in the field — either a new person
  /// ([parentHoldingId] `null`) or a new parcel for an existing person
  /// ([parentHoldingId] set to that person's `Parcel.id`). Awaits the
  /// Supabase insert first; [_parcels] is only mutated once the server has
  /// confirmed the write, so a failed write leaves the in-memory dataset
  /// untouched and propagates the exception to the caller.
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
        ? (parent.personId ?? parent.pendingGroupId ?? parent.id)
        : null;

    final String generatedId = _uuid.v4();
    final String? personId = parcel.personId ??
        (parent != null && parent.isHoldingIdPending
            ? (parent.personId ?? parent.pendingGroupId ?? parent.id)
            : generatedId);
    final Parcel withId = parcel.copyWith(
      id: generatedId,
      sourceAddedHoldingId: generatedId,
      personId: personId,
      pendingGroupId: pendingGroupId,
      isFieldAdded: true,
    );

    // `added_holdings.parent_holding_id` is a foreign key into the
    // canonical `holdings` table, not into `added_holdings` — it's only
    // ever valid once a record has been reviewed/promoted server-side.
    // `parent.isFieldAdded` (durable, persisted on every parcel — set here
    // and in the row mappers) is true for exactly the parcels whose `id`
    // lives in `added_holdings`, not `holdings`: `downloadHoldings` only
    // ever fetches unpromoted `added_holdings` rows (`promoted_holding_id
    // is null`), so a promoted record is never re-delivered as
    // `isFieldAdded: true` — it arrives as an ordinary `holdings` row
    // instead. Sending an `added_holdings.id` as `parent_holding_id` would
    // be rejected with a permanent FK violation, so it's sent as `null`
    // instead — same as a brand-new person with no known parent.
    final String? safeParentHoldingId =
        (parent != null && parent.isFieldAdded) ? null : parentHoldingId;

    final String? promotedHoldingId = await _syncService.syncAddParcel(
      parcelId: withId.id,
      cityId: cityId,
      parcel: withId,
      parentHoldingId: safeParentHoldingId,
    );

    // `added_holdings_auto_approve` (a DB trigger) promotes every new
    // record into `holdings` synchronously, in the same transaction as the
    // insert above — so by the time `addRecord` returns, the row this
    // client just created has *already* been superseded by a `holdings`
    // row. Reflecting that immediately (rather than waiting on Realtime to
    // deliver the trigger's own INSERT/UPDATE events and reconcile them)
    // is what avoids the person briefly appearing under its pre-promotion
    // id before "moving" to a different-looking entry once Realtime
    // catches up. Every field is already known client-side (it's exactly
    // what was just submitted) — no extra round-trip fetch needed, just
    // swap the id and flip `isFieldAdded` to match a `holdings`-origin row.
    final Parcel finalParcel = promotedHoldingId == null
        ? withId
        : withId.copyWith(id: promotedHoldingId, isFieldAdded: false);

    // Keep عدد القطع في الحيازة consistent across every parcel that shares
    // this holding — the new parcel's count already reflects the total
    // (set by the caller), so every sibling parcel is bumped to match it.
    if (parent != null) {
      _parcels = <Parcel>[
        for (final Parcel p in _parcels)
          if (p.groupKey == parent.groupKey)
            p.copyWith(holdingsCount: finalParcel.holdingsCount)
          else
            p,
      ];
    }

    _parcels = <Parcel>[..._parcels, finalParcel];
    _originalById[finalParcel.id] = finalParcel;
    _rebuildBorderIndex();
    return finalParcel;
  }

  /// Deletes a field-created record from the server (`added_holdings`) and
  /// drops it from the in-memory dataset once the delete is confirmed.
  /// Returns `false` without touching the server if [id] isn't in the
  /// active dataset or isn't a field-added record — part of the
  /// authoritative `holdings` import, which this app never deletes.
  /// Propagates the exception on a failed server delete rather than
  /// mutating local state.
  Future<bool> deleteLocalParcel(final String id) async {
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == id);
    if (idx < 0) return false;
    final Parcel removed = _parcels[idx];
    final String? addedHoldingId =
        removed.sourceAddedHoldingId ?? (removed.isFieldAdded ? removed.id : null);
    if (addedHoldingId == null) return false;

    await _syncService.syncDeleteParcel(addedHoldingId);

    _parcels = <Parcel>[
      for (final Parcel p in _parcels)
        if (p.id != id && p.sourceAddedHoldingId != addedHoldingId)
          // Mirrors addLocalParcel's bump: undo it for any sibling parcel
          // still sharing this holding.
          (p.groupKey == removed.groupKey && p.holdingsCount != null)
              ? p.copyWith(holdingsCount: p.holdingsCount! - 1)
              : p,
    ];
    _originalById.remove(id);
    _edits.remove(id);
    if (_activeEditsKey != null) {
      await _editsStore.save(_activeEditsKey!, _edits);
    }
    _rebuildBorderIndex();
    return true;
  }

  Parcel _applyEdit(final Parcel p) => _editOverlay.apply(p, _edits[p.id]);

  /// Persists an edited parcel — awaits the Supabase `holding_edits` insert
  /// first, and only reflects the change in [_parcels]/[_edits] once the
  /// server has confirmed it, so search/detail/border navigation never show
  /// a state the server hasn't accepted.
  @override
  Future<void> updateParcel(final Parcel edited) async {
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == edited.id);
    if (idx < 0) return;
    final Map<String, dynamic> snapshot = _editOverlay.snapshot(edited);

    final String? cityId = _activeCityId;
    if (cityId != null) {
      await _syncService.syncEditParcel(
        holdingId: edited.id,
        cityId: cityId,
        payload: snapshot,
      );
    }

    _parcels[idx] = edited;
    // A single-field edit can change حائز/مالك name — rebuild so a fresh
    // الحدود lookup elsewhere in the city sees the update immediately.
    _rebuildBorderIndex();
    _edits[edited.id] = snapshot;
    if (_activeEditsKey != null) {
      await _editsStore.save(_activeEditsKey!, _edits);
    }
  }

  /// Marks [parcelId] reviewed/un-reviewed — awaits the Supabase column
  /// UPDATE first, only reflecting it in [_parcels] once confirmed. Unlike
  /// [updateParcel] this never touches [_edits]/[ParcelEditsStore]: reviewed
  /// status is not part of the editable-field overlay.
  Future<Parcel?> setParcelReviewed(
    final String parcelId, {
    required final bool reviewed,
  }) async {
    final int idx = _parcels.indexWhere((final Parcel p) => p.id == parcelId);
    if (idx < 0) return null;

    final bool isFieldAdded = _parcels[idx].isFieldAdded;
    final Parcel updated = await _syncService.syncMarkReviewed(
      parcelId: parcelId,
      isFieldAdded: isFieldAdded,
      reviewed: reviewed,
      parcel: _parcels[idx],
    );

    _parcels[idx] = updated;
    _originalById[parcelId] = (_originalById[parcelId] ?? updated).copyWith(
      reviewed: updated.reviewed,
      reviewedAt: updated.reviewedAt,
      reviewedBy: updated.reviewedBy,
    );
    return updated;
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
  ///
  /// No longer guards against a stale/racing Realtime echo clobbering a
  /// fresher local `reviewed*` write (the previous `_pendingReviewedAt`
  /// mechanism): under online-first every local write only reaches
  /// [_parcels] after the server has already confirmed it (see
  /// [setParcelReviewed]), so there is no more "ahead of the server" window
  /// for an out-of-order echo to race against — by the time this device's
  /// own write lands locally, the server already has that exact value.
  ///
  /// [Parcel.pendingGroupId] IS still a case that needs guarding, though —
  /// unlike `reviewed*`, it has no column anywhere in `holdings`/
  /// `added_holdings`, so `holdingRowToParcel`/`addedHoldingRowToParcel`
  /// (and therefore [updated], which always comes from one of those two
  /// mappers) can never carry it; it only ever exists as client-side
  /// bookkeeping set once by [addLocalParcel]. Blindly replacing the
  /// existing entry with [updated] would silently null out a sibling
  /// parcel's `pendingGroupId` the moment this device's own INSERT/UPDATE
  /// echoes back over Realtime, un-grouping it from the pending person it
  /// was just correctly grouped with. Preserving the existing local value
  /// here is what keeps that grouping intact across the echo.
  @override
  void applyRemoteChange(final Parcel updated) {
    if (_activeCityId == null) return;

    final int idx = _parcels.indexWhere((final Parcel p) => p.id == updated.id);
    final Parcel updatedWithGroup = idx >= 0
        ? updated.copyWith(
            sourceAddedHoldingId:
                _parcels[idx].sourceAddedHoldingId ?? updated.sourceAddedHoldingId,
            pendingGroupId: _parcels[idx].pendingGroupId,
            personId: _parcels[idx].personId ?? updated.personId,
          )
        : updated;

    _originalById[updated.id] = updatedWithGroup;
    final Parcel toShow = _applyEdit(updatedWithGroup);
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
  /// parcel's current original value.
  ///
  /// Still skips applying the event if this device has its own edit for
  /// [holdingId] in [_edits] (`_edits.containsKey`) — kept deliberately
  /// rather than removed, even though the specific race it was written for
  /// (an offline-first local write staying authoritative until it synced)
  /// no longer exists. The remaining reason: `updateParcel` writes to
  /// [_edits] and awaits the Supabase insert in the same call, but the
  /// Realtime echo of that exact insert can still arrive back at this
  /// device (via [applyRemoteEdit]) essentially concurrently with
  /// `updateParcel`'s own local mutation completing — both derive from
  /// [_originalById], and re-merging the echo on top of an [_edits] entry
  /// that already reflects the *newer* full snapshot risks re-deriving a
  /// value that's momentarily stale relative to what's already on screen
  /// (e.g. if a second edit landed between the first insert and its echo
  /// arriving). Skipping when [_edits] already has an entry for this
  /// holding is a safe, cheap guard against that same-device echo
  /// clobbering newer local state — it does not skip a genuine remote
  /// correction from another device for a holding this device has never
  /// edited, since [_edits] would be empty for that holding.
  @override
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
  @override
  void applyRemoteDelete(final String id) {
    if (_activeCityId == null) return;
    final Parcel? removed = _parcels.cast<Parcel?>().firstWhere(
      (final Parcel? p) => p?.id == id || p?.sourceAddedHoldingId == id,
      orElse: () => null,
    );
    if (removed == null) return;

    _parcels = <Parcel>[
      for (final Parcel p in _parcels)
        if (p.id != id && p.sourceAddedHoldingId != id) p,
    ];
    _originalById.remove(removed.id);
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
  /// [basin] (only parcels whose اسم الحوض matches). Awaits each row's
  /// Supabase insert directly (no outbox), continuing past a per-row
  /// failure rather than aborting the whole batch — a bulk edit spans many
  /// independent holdings, so one failure shouldn't silently discard
  /// progress on the rest. Returns how many rows succeeded and how many
  /// failed, for the caller to report a mixed result.
  @override
  Future<BulkEditOutcome> bulkApplyField({
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

    if (result.changedCount == 0) {
      return const BulkEditOutcome(succeeded: 0, failed: 0);
    }

    final String? cityId = _activeCityId;

    final List<Parcel> inScope = <Parcel>[];
    final List<Parcel> outOfScope = <Parcel>[];
    for (final Parcel p in result.parcels) {
      (basin == null || p.basinName == basin ? inScope : outOfScope).add(p);
    }

    // Snapshots are computed up front (keyed by id) so syncBulkEdit's
    // per-parcel snapshot callback and this method's own success/failure
    // bookkeeping agree on the exact same payload per row.
    final Map<String, Map<String, dynamic>> snapshots = <String, Map<String, dynamic>>{
      for (final Parcel p in inScope) p.id: _editOverlay.snapshot(p),
    };

    final BulkSyncResult syncResult = await _syncService.syncBulkEdit(
      parcels: inScope,
      cityId: cityId,
      snapshotForParcel: (final Parcel p) => snapshots[p.id]!,
    );

    final List<Parcel> nextInScope = <Parcel>[];
    for (final Parcel p in inScope) {
      if (!syncResult.failedIds.contains(p.id)) {
        _edits[p.id] = snapshots[p.id]!;
        nextInScope.add(p);
      } else {
        // Row failed — keep its pre-bulk-edit value both on screen and in
        // [_edits] rather than a value the server never confirmed.
        nextInScope.add(_originalById[p.id] != null ? _applyEdit(p) : p);
      }
    }

    _parcels = <Parcel>[...nextInScope, ...outOfScope];
    // Defensive: no `BulkEditableField` touches حائز/مالك today, but
    // rebuilding here is O(n) same as the reassignment above and keeps
    // this repository from silently drifting out of sync if that ever
    // changes, without needing every future field to remember this rule.
    _rebuildBorderIndex();
    if (syncResult.outcome.succeeded > 0 && _activeEditsKey != null) {
      await _editsStore.save(_activeEditsKey!, _edits);
    }
    return syncResult.outcome;
  }
}
