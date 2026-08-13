import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get_it/get_it.dart' show GetIt;
import 'package:uuid/uuid.dart';

import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../cities/data/holding_row_mapper.dart';
import '../../../cities/domain/entities/association_type.dart';
import '../../../cities/domain/entities/city.dart';
import '../../../cities/domain/repositories/city_repository.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/networking/network_info.dart';
import '../../../sync/data/holdings_api.dart';
import '../../../sync/data/realtime_sync_service.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/parcel_change_handler.dart';
import '../../../sync/domain/services/sync_runner.dart';
import '../../domain/entities/bulk_edit_outcome.dart';
import '../../domain/entities/bulk_editable_field.dart';
import '../../domain/entities/parcel.dart';
import '../../domain/repositories/holdings_reader.dart';
import '../../domain/repositories/holdings_writer.dart';
import '../../domain/services/bulk_edit_service.dart';
import '../../domain/services/parcel_edit_overlay.dart';
import '../../domain/services/parcel_query_service.dart';
import '../../domain/services/holding_search_service.dart';
import '../services/parcel_sync_service.dart';
import 'parcel_dataset_state.dart';
import 'parcel_edits_store.dart';

/// Orchestrates writes/realtime application against the active city's
/// dataset — search, detail, and the bulk-edit screen all read from here.
/// The Excel-file-picker path this class used to also support was retired
/// in APP_PLAN.md Phase 5; a city download is the only way data gets in now
/// (see `CityPickerCubit.downloadAndActivate` / `loadParcelsForCity`).
///
/// State (the active dataset, local edit overlay, border index) lives in
/// [ParcelDatasetState] — this class calls into it but doesn't hold that
/// state itself, keeping its own responsibility to "know how to perform
/// each write/realtime-apply operation," not "be the dataset."
///
/// **Online-first-when-possible, outbox-when-offline (`REFACTOR_ROADMAP.md`
/// Phase 19, revising Phase 9 #9's pure-outbox model):** every write method
/// (`addLocalParcel`, `deleteLocalParcel`, `updateParcel`,
/// `setParcelCompleted`, `bulkApplyField`) checks [_isOnline] first. When
/// online, it calls straight into [_syncService] and **awaits** the
/// network round-trip before applying anything locally or returning — a
/// caller only sees success once the server has actually confirmed the
/// write, and a failure throws instead of silently landing in the outbox
/// with the UI already showing success. Only when genuinely offline (or no
/// [_syncRunner]/[_networkInfo] configured at all, e.g. most repository
/// tests) does a write fall back to the old optimistic
/// apply-then-enqueue-via-[_syncRunner] path — mutating the in-memory
/// dataset immediately and enqueuing a durable [SyncOperation] for
/// [_syncRunner] to execute and retry in the background (`SyncRunner.flush`,
/// triggered on enqueue and on reconnect/app-resume). A permanently-failed
/// queued operation (past `SyncRunner.maxAttempts`) stays visible in
/// `SyncRunner.operations` for a "failed syncs" UI to surface and let the
/// user retry or discard, rather than being silently dropped. This
/// preserves offline-first (a queued write is never blocked on network)
/// while making the common online case honest about what "success" means.
class HoldingsRepository
    implements HoldingsReader, HoldingsWriter, ParcelChangeHandler {
  HoldingsRepository({
    final ParcelDatasetState? datasetState,
    final ParcelEditsStore editsStore = const ParcelEditsStore(),
    final ParcelEditOverlay editOverlay = const ParcelEditOverlay(),
    final ParcelQueryService queryService = const ParcelQueryService(),
    final BulkEditService bulkEditService = const BulkEditService(),
    this.holdingsApi,
    this.realtimeSyncService,
    final Uuid uuid = const Uuid(),
    final ParcelSyncService? syncService,
    final SyncRunner? syncRunner,
    final NetworkInfo? networkInfo,
  })  : _dataset = datasetState ??
            ParcelDatasetState(editsStore: editsStore, editOverlay: editOverlay),
        _queryService = queryService,
        _bulkEditService = bulkEditService,
        _uuid = uuid,
        _syncService = syncService ?? ParcelSyncService(holdingsApi: holdingsApi),
        _syncRunner = syncRunner,
        _networkInfo = networkInfo;

  final ParcelDatasetState _dataset;
  final ParcelQueryService _queryService;
  final BulkEditService _bulkEditService;
  final Uuid _uuid;
  final ParcelSyncService _syncService;

  /// `null` in tests that don't exercise the outbox path — every write
  /// method falls back to enqueueing nothing (matching the prior
  /// `holdingsApi == null` "no-op network call" test convention) when this
  /// is unset, so existing repository tests that assert on immediate local
  /// state don't need an outbox double just to construct the repository.
  final SyncRunner? _syncRunner;

  /// `null` in tests that construct this repository without a real network
  /// dependency — [_isOnline] treats a `null` [_networkInfo] as "online"
  /// (matching the prior always-optimistic behavior), so existing tests
  /// that assert on the optimistic/outbox path keep working unchanged.
  final NetworkInfo? _networkInfo;

  /// Whether a write should attempt the synchronous, awaited path
  /// (`REFACTOR_ROADMAP.md` Phase 19) instead of the optimistic
  /// apply-then-enqueue one. Every write method below checks this — when
  /// `true`, it calls straight into [_syncService] and only shows success
  /// to the caller once that `Future` resolves, so a failure surfaces as a
  /// real thrown error instead of silently landing in the outbox with a
  /// success snackbar already shown. When `false` (genuinely offline, or no
  /// [_syncRunner] configured to fall back to at all), the existing
  /// optimistic-apply-and-enqueue path is unchanged — offline-first is
  /// fully preserved, this only changes what happens when a network call
  /// could actually have been made.
  Future<bool> _isOnline() async {
    if (_syncRunner == null) return true;
    final NetworkInfo? info = _networkInfo;
    if (info == null) return true;
    return info.isConnected;
  }

  /// Enqueues [operation] and kicks off a best-effort immediate flush —
  /// fire-and-forget on purpose (`REFACTOR_ROADMAP.md` Phase 9 #9): the
  /// calling write method has already returned to the UI by the time this
  /// runs, since it's called without awaiting. A slow/offline flush simply
  /// leaves the operation queued for the next trigger (reconnect, app
  /// resume, or the next unrelated write's own flush attempt).
  void _enqueue(final SyncOperation operation) {
    final SyncRunner? runner = _syncRunner;
    if (runner == null) return;
    runner.enqueue(operation);
    unawaited(runner.flush());
  }

  /// `null` in tests that construct this repository directly without a
  /// Supabase-backed API — every write method treats a `null` [holdingsApi]
  /// as a no-op network call (mutates local state as if the write
  /// succeeded), which is what lets the existing add/delete/completed tests
  /// construct a repository with no network dependency at all.
  final HoldingsApi? holdingsApi;

  /// `null` in tests that construct this repository directly without a
  /// Realtime service — [loadParcelsForCity] simply skips the subscribe
  /// call in that case, same "optional dependency, no-op if absent"
  /// pattern as [holdingsApi].
  final RealtimeSyncService? realtimeSyncService;

  Stream<void> get onRemoteChange => _dataset.onRemoteChange;

  @override
  List<Parcel> get parcels => _dataset.parcels;

  /// The currently loaded city's id — `null` until a city is loaded.
  /// Exposed for city-scoped maintenance screens (e.g. per-city نوع الزرع
  /// management) that need it but aren't part of the parcel-sync flow.
  String? get activeCityId => _dataset.activeCityId;

  /// Adopts a city-downloaded (or cache-loaded) parcel list as the active
  /// dataset. [associationType]/[associationSubtype] come straight from the
  /// `CitySnapshot` (itself read from `cities.association_type`/
  /// `association_subtype`) — never re-derived from [parcels].
  ///
  /// [dataVersion], when provided, is remembered as [_activeDataVersion] so
  /// [syncNow] can compare it against the server's current version before
  /// deciding whether a full re-download is actually needed (see that
  /// method's doc comment) — every call site already has a `CitySnapshot`
  /// in hand at the point it calls this, so threading the version through
  /// costs nothing extra there.
  Future<List<Parcel>> loadParcelsForCity(
    final String cityId,
    final List<Parcel> parcels, {
    final String? cityName,
    final String? directorate,
    final String? administration,
    final AssociationType? associationType,
    final String? associationSubtype,
    final int? dataVersion,
  }) async {
    final List<Parcel> result = await _dataset.adopt(
      cityId,
      parcels,
      cityName: cityName,
      directorate: directorate,
      administration: administration,
      associationType: associationType,
      associationSubtype: associationSubtype,
    );
    if (dataVersion != null) _activeDataVersion = dataVersion;
    // Realtime tracks exactly one active city, same as this repository —
    // re-subscribing here (rather than at the CityPickerCubit call site)
    // means it also fires for a cache-loaded city at app start, not just a
    // fresh download.
    realtimeSyncService?.subscribeToCity(cityId);
    return result;
  }

  /// The data_version the active city's dataset was last loaded/refreshed
  /// at, as of the most recent [loadParcelsForCity] call that passed one —
  /// `null` until then (e.g. tests that call [loadParcelsForCity] without
  /// it). Used only to decide whether [syncNow] can skip a redundant
  /// re-download; never gates a write.
  int? _activeDataVersion;

  /// The active city's جمعية system, read from `cities.association_type` —
  /// `null` until a city is loaded or if the dashboard hasn't set it yet.
  AssociationType? get activeAssociationType => _dataset.activeAssociationType;

  /// The active city's free-text association_subtype (e.g. ملك/أوقاف or one
  /// of the three إصلاح variants) — `null` until a city is loaded or if
  /// unset in the database.
  String? get activeAssociationSubtype => _dataset.activeAssociationSubtype;

  /// Whether نوع الائتمان should be hidden everywhere in the UI — true only
  /// for a confirmed الإصلاح الزراعي city. `null` (type not set in the DB
  /// yet) shows the field rather than risk hiding one that might matter —
  /// same "never hide on an unknown" philosophy the old detection-miss
  /// fallback used.
  bool get hideCreditType =>
      _dataset.activeAssociationType == AssociationType.agriculturalReform;

  /// The default association name (اسم الجمعية) from the active city's
  /// dataset — used to auto-populate this field for new records so they're
  /// consistent. Returns the first non-empty association name found, or
  /// `null` if none exist in the active dataset.
  String? get defaultAssociationName {
    for (final Parcel p in _dataset.parcels) {
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
  ///
  /// Skips the actual re-download when the server's `data_version` hasn't
  /// advanced past [_activeDataVersion] — otherwise every pull-to-refresh
  /// re-transfers the entire city (thousands of rows) even when nothing
  /// changed, which is exactly what was driving this project's Supabase
  /// egress usage before this guard existed. A write (add/edit/delete/
  /// complete) never goes through this path at all — those always call
  /// straight into `_syncService`/`_syncRunner` and are never skipped.
  Future<void> syncNow() async {
    final String? cityId = _dataset.activeCityId;
    final String? cityName = _dataset.activeCityName;
    if (cityId == null || cityName == null) return;

    final CityRepository cityRepository = GetIt.instance<CityRepository>();
    final int remoteVersion = await cityRepository.remoteDataVersion(cityId);
    final int? localVersion = _activeDataVersion;
    if (localVersion != null && remoteVersion <= localVersion) return;

    final City city = City(
      id: cityId,
      name: cityName,
      status: CityStatus.published,
      dataVersion: remoteVersion,
      directorate: _dataset.activeDirectorate,
      administration: _dataset.activeAdministration,
      associationType: _dataset.activeAssociationType,
      associationSubtype: _dataset.activeAssociationSubtype,
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
      dataVersion: fresh.dataVersion,
    );
  }

  /// اسم الحائز/المالك كما يظهر في بطاقة الفلاح is no longer a
  /// user-entered field (`REFACTOR_ROADMAP.md` Phase 10 §1) — it's derived
  /// from [Parcel.holderName]/[Parcel.ownerName] on every write, so the two
  /// stay in sync automatically instead of being typed twice. Applied at
  /// the [addLocalParcel]/[updateParcel] write boundary rather than inside
  /// [Parcel] itself, keeping the entity a plain data holder.
  Parcel _withDerivedFarmerCardNames(final Parcel parcel) => parcel.copyWith(
        holderNameFarmerCard: parcel.holderName,
        ownerNameFarmerCard: parcel.ownerName,
      );

  /// Adds a brand-new record created in the field — either a new person
  /// ([parentHoldingId] `null`) or a new parcel for an existing person
  /// ([parentHoldingId] set to that person's `Parcel.id`).
  ///
  /// **Outbox model:** the local dataset is mutated immediately
  /// (optimistic) and an [AddParcelOperation] is enqueued in the same call
  /// — this method does not await the Supabase insert when a [_syncRunner]
  /// is configured. The server-side promotion into `holdings` (previously
  /// reconciled synchronously here by swapping in `promotedHoldingId`) now
  /// arrives later via the normal Realtime path (`applyRemoteChange`), same
  /// as any other device's write — see `AddParcelSyncHandler`'s doc for why
  /// duplicating that reconciliation here would be redundant.
  ///
  /// Does nothing (returns `null`) if no city is active.
  Future<Parcel?> addLocalParcel(
    final Parcel parcel, {
    final String? parentHoldingId,
  }) async {
    final String? cityId = _dataset.activeCityId;
    if (cityId == null) return null;

    // Falls back to a sourceAddedHoldingId match when the exact id isn't
    // found — [parentHoldingId] is a snapshot of the parent's id taken by
    // the caller (e.g. `DetailScreen._addParcelForPerson`'s own, possibly
    // stale `_parcels` list) at some point before this call; if that parent
    // was synchronously promoted server-side in between (its `id` changing
    // from the pre-promotion `added_holdings` id to the new `holdings` id),
    // an exact-id-only lookup would miss it entirely and this call would
    // silently treat the new parcel as belonging to a brand-new, unrelated
    // person instead of joining the existing one's group — with no error
    // surfaced anywhere. The promoted entry still carries the pre-promotion
    // id as its `sourceAddedHoldingId`, which is exactly what
    // [parentHoldingId] would equal in that case.
    final Parcel? parent = parentHoldingId == null
        ? null
        : _dataset.parcels.cast<Parcel?>().firstWhere(
            (final Parcel? p) => p?.id == parentHoldingId,
            orElse: () => _dataset.parcels.cast<Parcel?>().firstWhere(
                  (final Parcel? p) =>
                      p?.sourceAddedHoldingId == parentHoldingId,
                  orElse: () => null,
                ),
          );

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
    final String personId = parcel.personId ??
        (parent != null && parent.isHoldingIdPending
            ? (parent.personId ?? parent.pendingGroupId ?? parent.id)
            : generatedId);
    final Parcel withId = _withDerivedFarmerCardNames(
      parcel.copyWith(
        id: generatedId,
        sourceAddedHoldingId: generatedId,
        personId: personId,
        pendingGroupId: pendingGroupId,
        isFieldAdded: true,
      ),
    );

    // `added_holdings.parent_holding_id` is a foreign key into the
    // canonical `holdings` table, not into `added_holdings` — it's only
    // ever valid once a record has been reviewed/promoted server-side.
    // Uses `parent.isCurrentlyInAddedHoldings`, not `parent.isFieldAdded` —
    // the latter is a permanent provenance marker (`REFACTOR_ROADMAP.md`
    // Phase 24/25: `holdings.is_field_added` stays `true` forever once a
    // row is promoted, for the "مضافة من التطبيق" badge), so it can no
    // longer tell "still in added_holdings" from "already promoted into
    // holdings" — `isCurrentlyInAddedHoldings` is the field that actually
    // flips at promotion. Sending an `added_holdings.id` as
    // `parent_holding_id` would be rejected with a permanent FK violation,
    // so it's sent as `null` instead — same as a brand-new person with no
    // known parent.
    final String? safeParentHoldingId =
        (parent != null && parent.isCurrentlyInAddedHoldings)
            ? null
            : parentHoldingId;

    void applyLocally(final Parcel finalParcel) {
      // Keep عدد القطع في الحيازة consistent across every parcel that shares
      // this holding — the new parcel's count already reflects the total
      // (set by the caller), so every sibling parcel is bumped to match it.
      if (parent != null) {
        _dataset.replaceAll(<Parcel>[
          for (final Parcel p in _dataset.parcels)
            if (p.groupKey == parent.groupKey)
              p.copyWith(holdingsCount: finalParcel.holdingsCount)
            else
              p,
        ]);
      }
      // upsert, not append: a synchronously-promoted parcel races its own
      // Realtime echo (the `added_holdings` INSERT and/or the promoted
      // `holdings` INSERT for the exact same underlying row) — if that echo
      // is processed on this device before this awaited call returns,
      // `applyRemoteChange` will have already added an entry for it under
      // either the pre-promotion or promoted id. A blind append here would
      // then leave two entries for the same parcel instead of reconciling
      // with whichever arrived first.
      _dataset.upsert(finalParcel);
      _dataset.setOriginal(finalParcel.id, finalParcel);
      _dataset.rebuildBorderIndex();
    }

    if (_syncRunner != null && !await _isOnline()) {
      // Genuinely offline: apply locally first, enqueue, return without
      // awaiting the network. The server-side promotion swap the online
      // path below does synchronously now arrives later via Realtime —
      // see this method's doc.
      applyLocally(withId);
      _enqueue(
        AddParcelOperation(
          operationId: _uuid.v4(),
          createdAt: DateTime.now(),
          cityId: cityId,
          parcel: withId,
          parentHoldingId: safeParentHoldingId,
        ),
      );
      return withId;
    }

    // Online (or no outbox configured — test-mode/no-network path, mirrors
    // the old `holdingsApi == null` convention): await-then-mutate — a
    // failed write must leave the dataset completely untouched, and a
    // synchronously-promoted row must be shown under its final id
    // immediately, never briefly under the pre-promotion one. A caller only
    // sees success once the server has actually confirmed the insert
    // (`REFACTOR_ROADMAP.md` Phase 19).
    final String? promotedHoldingId = await _syncService.syncAddParcel(
      parcelId: withId.id,
      cityId: cityId,
      parcel: withId,
      parentHoldingId: safeParentHoldingId,
    );
    final Parcel finalParcel = promotedHoldingId == null
        ? withId
        : withId.copyWith(id: promotedHoldingId, isFieldAdded: false);
    applyLocally(finalParcel);
    return finalParcel;
  }

  /// Deletes a field-created record — drops it from the in-memory dataset
  /// immediately (optimistic) and enqueues a [DeleteParcelOperation].
  /// Returns `false` without touching local state or the server if [id]
  /// isn't in the active dataset or isn't a field-added record — part of
  /// the authoritative `holdings` import, which this app never deletes.
  Future<bool> deleteLocalParcel(final String id) async {
    final int idx = _dataset.indexOf(id);
    if (idx < 0) return false;
    final Parcel removed = _dataset.parcels[idx];
    final String? addedHoldingId =
        removed.sourceAddedHoldingId ?? (removed.isFieldAdded ? removed.id : null);
    if (addedHoldingId == null) return false;

    Future<void> applyLocally() async {
      // Matches by exact `id` only — deliberately not also by
      // `sourceAddedHoldingId`, the same unsafe wildcard-match shape
      // `ParcelDatasetState.removeWhereIdOrSource` was narrowed away from
      // (see its doc comment): a promoted parcel's `sourceAddedHoldingId`
      // still points at its pre-promotion `added_holdings` row, and nothing
      // guarantees that value stays unique to just the one row being
      // deleted here forever, so matching on it as a second, broader
      // condition risks silently deleting an unrelated parcel that happens
      // to share it.
      _dataset.replaceAll(<Parcel>[
        for (final Parcel p in _dataset.parcels)
          if (p.id != id)
            // Mirrors addLocalParcel's bump: undo it for any sibling parcel
            // still sharing this holding.
            (p.groupKey == removed.groupKey && p.holdingsCount != null)
                ? p.copyWith(holdingsCount: p.holdingsCount! - 1)
                : p,
      ]);
      _dataset.removeOriginal(id);
      _dataset.removeEdit(id);
      await _dataset.persistEdits();
      _dataset.rebuildBorderIndex();
    }

    if (_syncRunner != null && !await _isOnline()) {
      // Genuinely offline: apply locally first, enqueue, return without
      // awaiting the network.
      await applyLocally();
      _enqueue(
        DeleteParcelOperation(
          operationId: _uuid.v4(),
          createdAt: DateTime.now(),
          addedHoldingId: addedHoldingId,
        ),
      );
      return true;
    }

    // Online (or no outbox configured): await-then-mutate — a failed server
    // delete must leave local state untouched, and the caller only sees
    // success once the server has confirmed it (`REFACTOR_ROADMAP.md`
    // Phase 19).
    await _syncService.syncDeleteParcel(addedHoldingId);
    await applyLocally();
    return true;
  }

  /// Persists an edited parcel (`REFACTOR_ROADMAP.md` Phase 19). When
  /// online, awaits the Supabase `holding_edits` insert *before* applying
  /// the edit to the local dataset/overlay — a failure throws and leaves
  /// the dataset untouched, instead of showing the edit as saved before the
  /// server has confirmed it. Only when genuinely offline does this apply
  /// optimistically and enqueue an [EditParcelOperation] for later.
  @override
  Future<void> updateParcel(final Parcel rawEdited) async {
    final Parcel edited = _withDerivedFarmerCardNames(rawEdited);
    final int idx = _dataset.indexOf(edited.id);
    if (idx < 0) return;
    final Map<String, dynamic> snapshot = _dataset.editSnapshot(edited);
    final String? cityId = _dataset.activeCityId;

    // Re-resolves the index rather than closing over a fixed one — a
    // Realtime event can append/remove entries in the dataset while an
    // awaited network call above is in flight, shifting every later
    // position; applying at a stale index could silently overwrite an
    // unrelated parcel.
    bool applyLocally() {
      final int freshIdx = _dataset.indexOf(edited.id);
      if (freshIdx < 0) return false;
      _dataset.replaceAt(freshIdx, edited);
      // A single-field edit can change حائز/مالك name — rebuild so a fresh
      // الحدود lookup elsewhere in the city sees the update immediately.
      _dataset.rebuildBorderIndex();
      _dataset.setEdit(edited.id, snapshot);
      return true;
    }

    if (cityId != null && _syncRunner != null && await _isOnline()) {
      await _syncService.syncEditParcel(
        holdingId: edited.id,
        cityId: cityId,
        payload: snapshot,
      );
      applyLocally();
      await _dataset.persistEdits();
      return;
    }

    applyLocally();
    await _dataset.persistEdits();

    if (cityId == null) return;

    if (_syncRunner != null) {
      _enqueue(
        EditParcelOperation(
          operationId: _uuid.v4(),
          createdAt: DateTime.now(),
          holdingId: edited.id,
          cityId: cityId,
          payload: snapshot,
        ),
      );
    } else {
      await _syncService.syncEditParcel(
        holdingId: edited.id,
        cityId: cityId,
        payload: snapshot,
      );
    }
  }

  /// Marks [parcelId] completed/reopened — the field-worker signal
  /// (`SYSTEM_DESIGN.md` §10; `REFACTOR_ROADMAP.md` Phase 9 #12/Phase 19).
  /// Writes `completed_at`/`completed_by`, never `reviewed`/`reviewed_at`/
  /// `reviewed_by` (staff/Dashboard-only). Unlike [updateParcel] this never
  /// touches the edit overlay: completion status is not part of the
  /// editable-field overlay.
  ///
  /// When online (`_isOnline`), calls straight into [_syncService] and
  /// awaits it — a caller only sees this return once the server has
  /// actually confirmed the write, and a failure (including
  /// [ConflictException] from `mark_parcel_completed`'s atomic guard when
  /// another device already completed this parcel) throws instead of
  /// silently applying locally. Only when genuinely offline does this fall
  /// back to the optimistic apply-then-enqueue path.
  Future<Parcel?> setParcelCompleted(
    final String parcelId, {
    required final bool completed,
  }) async {
    debugPrint(
      '[setParcelCompleted] called: parcelId=$parcelId, completed=$completed',
    );
    final int idx = _dataset.indexOf(parcelId);
    if (idx < 0) {
      debugPrint(
        '[setParcelCompleted] parcelId=$parcelId not found in local dataset '
        '— returning null (no-op)',
      );
      return null;
    }

    // `Parcel.isFieldAdded` is provenance, not live table location — it
    // stays `true` forever on a promoted parcel (see its doc). What the RPC
    // actually needs is `isCurrentlyInAddedHoldings`, which correctly
    // flips to `false` the moment a row is promoted.
    final bool inAddedHoldings = _dataset.parcels[idx].isCurrentlyInAddedHoldings;
    final bool online = _syncRunner == null || await _isOnline();
    debugPrint(
      '[setParcelCompleted] parcelId=$parcelId inAddedHoldings=$inAddedHoldings '
      'online=$online',
    );

    if (online) {
      try {
        final Parcel updated = await _syncService.syncMarkCompleted(
          parcelId: parcelId,
          isFieldAdded: inAddedHoldings,
          completed: completed,
          parcel: _dataset.parcels[idx],
        );
        debugPrint('[setParcelCompleted] parcelId=$parcelId RPC confirmed');
        // Re-resolves the index rather than reusing the pre-await [idx]: a
        // Realtime event can append/remove entries in [_dataset.parcels]
        // while this RPC is in flight, which would shift every later index —
        // applying at a stale position could silently overwrite an unrelated
        // parcel. `indexOf` is cheap (id equality scan) and this write is not
        // hot-path-frequent enough for it to matter.
        final int freshIdx = _dataset.indexOf(parcelId);
        if (freshIdx < 0) return updated;
        _applyCompletedLocally(parcelId, freshIdx, updated);
        return updated;
      } catch (error) {
        debugPrint(
          '[setParcelCompleted] parcelId=$parcelId threw '
          '${error.runtimeType}: $error',
        );
        rethrow;
      }
    }

    final DateTime? completedAt = completed ? DateTime.now() : null;
    final String? currentUserId =
        GetIt.instance<AuthRepository>().currentUser?.id;
    final Parcel updated = _dataset.parcels[idx].copyWith(
      completedAt: completedAt,
      completedBy: completed ? currentUserId : null,
    );
    _applyCompletedLocally(parcelId, idx, updated);

    _enqueue(
      CompleteParcelOperation(
        operationId: _uuid.v4(),
        createdAt: DateTime.now(),
        parcelId: parcelId,
        isFieldAdded: inAddedHoldings,
        completed: completed,
        completedAt: completedAt,
        completedByUserId: currentUserId ?? '',
      ),
    );
    return updated;
  }

  /// Re-reads [parcelId] from the server and applies whatever it finds via
  /// [applyRemoteChange] — the reconciliation step for a write whose local
  /// outcome is genuinely unknown (`REFACTOR_ROADMAP.md` Phase 25), e.g.
  /// [setParcelCompleted] timing out after the RPC may have already
  /// committed server-side. Returns the reconciled [Parcel] if found, or
  /// `null` if the row couldn't be read (still offline, or genuinely not
  /// found) — a `null` here means "still uncertain," not "confirmed absent,"
  /// so callers must not treat it as a negative result.
  Future<Parcel?> refreshParcel(final String parcelId) async {
    debugPrint('[refreshParcel] reconciling parcelId=$parcelId');
    if (holdingsApi == null) {
      debugPrint('[refreshParcel] no holdingsApi configured — returning null');
      return null;
    }
    // Deliberately does NOT pass the local dataset's `isFieldAdded` as a
    // hint — reconciliation exists precisely because that locally-cached
    // flag might be the stale value that caused the ambiguity in the first
    // place (e.g. a parcel promoted from `added_holdings` into `holdings`
    // whose local `isFieldAdded` never got flipped to `false`). Passing
    // `null` makes `fetchParcelById` check both tables rather than only the
    // one the stale flag points at, same failure this was meant to recover
    // from otherwise repeating itself.
    final result = await holdingsApi!.fetchParcelById(parcelId);
    if (result == null) {
      debugPrint('[refreshParcel] parcelId=$parcelId still not found — uncertain');
      return null;
    }
    final Parcel refreshed = result.isFieldAdded
        ? addedHoldingRowToParcel(result.row)
        : holdingRowToParcel(result.row);
    debugPrint(
      '[refreshParcel] parcelId=$parcelId reconciled, '
      'completedAt=${refreshed.completedAt}',
    );
    applyRemoteChange(refreshed);
    return refreshed;
  }

  /// [setParcelCompleted], but reconciles-and-retries once on
  /// [NotFoundException] instead of surfacing it straight to the caller —
  /// shared by Copy ID (`ParcelDetailCard._copyId`) and إعادة الفتح
  /// (`DetailScreen._reopenParcel`), which both hit the exact same failure
  /// mode: the RPC's `p_is_field_added`/id pairing not matching any row in
  /// the table it targeted, because this device's cached
  /// [Parcel.isCurrentlyInAddedHoldings] is stale (the parcel was promoted
  /// between `added_holdings`/`holdings` server-side after this screen
  /// loaded). A timeout means the write may have already committed — reconcile
  /// but the outcome is genuinely unknown — is left to the caller and
  /// deliberately NOT retried here. [ConflictException] (another device
  /// already applied the same value) is also left to the caller, since both
  /// callers show different, action-specific messages for these two cases and
  /// don't want a generic shared one.
  Future<Parcel?> setParcelCompletedWithReconciliation(
    final String parcelId, {
    required final bool completed,
  }) async {
    try {
      return await setParcelCompleted(parcelId, completed: completed);
    } on NotFoundException catch (error) {
      debugPrint(
        '[setParcelCompletedWithReconciliation] parcelId=$parcelId '
        'NotFoundException: $error — stale table assumption, reconciling '
        'then retrying once',
      );
      await refreshParcel(parcelId);
      return setParcelCompleted(parcelId, completed: completed);
    }
  }

  void _applyCompletedLocally(
    final String parcelId,
    final int idx,
    final Parcel updated,
  ) {
    _dataset.replaceAt(idx, updated);
    final Parcel? original = _dataset.originalParcel(parcelId);
    _dataset.setOriginal(
      parcelId,
      (original ?? updated).copyWith(
        completedAt: updated.completedAt,
        completedBy: updated.completedBy,
      ),
    );
  }

  /// Reverts a parcel to its original parsed values.
  @override
  Future<void> resetParcel(final String id) async {
    final Parcel? original = _dataset.originalParcel(id);
    if (original == null) return;
    final int idx = _dataset.indexOf(id);
    if (idx >= 0) _dataset.replaceAt(idx, original);
    _dataset.removeEdit(id);
    await _dataset.persistEdits();
  }

  /// Patches a single parcel arriving from a Supabase Realtime `holdings`/
  /// `added_holdings` INSERT or UPDATE event (already mapped to a [Parcel]
  /// by `holdingRowToParcel`/`addedHoldingRowToParcel` — this method does no
  /// parsing of its own). Replaces the parcel by id if it already exists in
  /// the dataset, or appends it if this is the first this device has seen
  /// of it (e.g. another device just added it). The original-value map is
  /// always updated to the new server-confirmed value, since it represents
  /// "what the server has" for [resetParcel] purposes regardless of what's
  /// shown.
  ///
  /// Does nothing if no city is active or [updated] belongs to a different
  /// city than the one currently loaded — a stray event from a
  /// slow-to-unsubscribe previous city's channel should never mutate the
  /// dataset the user is currently looking at.
  ///
  /// No longer guards against a stale/racing Realtime echo clobbering a
  /// fresher local `reviewed*` write (the previous `_pendingReviewedAt`
  /// mechanism): under online-first every local write only reaches the
  /// dataset after the server has already confirmed it (see
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
    if (_dataset.activeCityId == null) return;

    // A just-promoted `holdings` row arrives with a brand-new
    // server-generated `id` — matching on `id` alone would miss the
    // pre-promotion local entry entirely and append this as a *second*,
    // duplicate parcel instead of replacing it in place. `sourceAddedHoldingId`
    // is what still ties the two together (set locally in `addLocalParcel`
    // and echoed back on the promoted row by the DB migration that added
    // `holdings.source_added_holding_id`).
    final int idx = _dataset.indexOfForRemoteChange(updated);
    final Parcel updatedWithGroup = idx >= 0
        ? updated.copyWith(
            sourceAddedHoldingId: _dataset.parcels[idx].sourceAddedHoldingId ??
                updated.sourceAddedHoldingId,
            pendingGroupId: _dataset.parcels[idx].pendingGroupId,
            personId: _dataset.parcels[idx].personId ?? updated.personId,
          )
        : updated;

    if (idx >= 0 && _dataset.parcels[idx].id != updated.id) {
      // The old id (pre-promotion local id) is being replaced by the new
      // server id — drop its now-stale original/edit-overlay bookkeeping so
      // it doesn't linger under an id nothing points to any more.
      _dataset.removeOriginal(_dataset.parcels[idx].id);
      _dataset.removeEdit(_dataset.parcels[idx].id);
    }

    _dataset.setOriginal(updatedWithGroup.id, updatedWithGroup);
    final Parcel toShow = _dataset.applyEdit(updatedWithGroup);
    if (idx >= 0) {
      _dataset.replaceAt(idx, toShow);
    } else {
      _dataset.append(toShow);
    }
    _dataset.rebuildBorderIndex();
    _dataset.notifyRemoteChange();
  }

  /// Merges a `holding_edits` INSERT event's payload (a `toEditableJson`-
  /// shaped map, same as the edit overlay's snapshot produces) onto the
  /// parcel's current original value.
  ///
  /// Still skips applying the event if this device has its own edit for
  /// [holdingId] — kept deliberately rather than removed, even though the
  /// specific race it was written for (an offline-first local write staying
  /// authoritative until it synced) no longer exists. The remaining reason:
  /// `updateParcel` writes the edit overlay and awaits the Supabase insert
  /// in the same call, but the Realtime echo of that exact insert can still
  /// arrive back at this device (via [applyRemoteEdit]) essentially
  /// concurrently with `updateParcel`'s own local mutation completing —
  /// both derive from the same original-value map, and re-merging the echo
  /// on top of an edit-overlay entry that already reflects the *newer* full
  /// snapshot risks re-deriving a value that's momentarily stale relative to
  /// what's already on screen (e.g. if a second edit landed between the
  /// first insert and its echo arriving). Skipping when the edit overlay
  /// already has an entry for this holding is a safe, cheap guard against
  /// that same-device echo clobbering newer local state — it does not skip
  /// a genuine remote correction from another device for a holding this
  /// device has never edited, since the overlay would be empty for that
  /// holding.
  @override
  void applyRemoteEdit(final String holdingId, final Map<String, dynamic> payload) {
    if (_dataset.activeCityId == null) return;
    if (_dataset.isParcelEdited(holdingId)) return;

    final Parcel? original = _dataset.originalParcel(holdingId);
    if (original == null) return;

    final int idx = _dataset.indexOf(holdingId);
    if (idx < 0) return;
    final Parcel merged = _dataset.applyPayload(original, payload);
    _dataset.replaceAt(idx, merged);
    _dataset.rebuildBorderIndex();
    _dataset.notifyRemoteChange();
  }

  /// Removes a parcel from the active dataset in response to a Supabase
  /// Realtime DELETE event — a holding marked stale, or an `added_holdings`
  /// row rejected/deleted server-side. No-op if [id] isn't in the active
  /// dataset (e.g. a stray event for a different city).
  @override
  void applyRemoteDelete(final String id) {
    if (_dataset.activeCityId == null) return;
    final Parcel? removed = _dataset.findByIdOrSource(id);
    if (removed == null) return;

    _dataset.removeWhereIdOrSource(id);
    _dataset.removeOriginal(removed.id);
    _dataset.rebuildBorderIndex();
    _dataset.notifyRemoteChange();
  }

  bool isParcelEdited(final String id) => _dataset.isParcelEdited(id);

  /// The pre-edit value of the parcel [id] — either the originally
  /// downloaded row, or (for a field-added record) the value at the moment
  /// it was created. `null` if [id] isn't in the active dataset. Used to
  /// drive per-field "معدلة" indicators by comparing each field against
  /// its own original value, rather than only knowing *that* something on
  /// the parcel changed (see `isParcelEdited`).
  Parcel? originalParcel(final String id) => _dataset.originalParcel(id);

  /// Searches within [basin] (اسم الحوض) if given, otherwise the whole
  /// dataset — narrowing the scope keeps matching fast on large cities.
  @override
  List<SearchResult> search(final String query, {final String? basin}) =>
      _queryService.search(_dataset.parcels, query, basin: basin);

  /// Live server-side follow-up to [search] (`REFACTOR_ROADMAP.md` Phase 9
  /// #7) — queries `holdings`/`added_holdings` directly for [query] and
  /// returns only the results not already present among [localResults]
  /// (matched by `groupKey`), so the merged list never duplicates a holding
  /// the local cache already found. Returns an empty list (rather than
  /// throwing) if no city is active or the query fails — this is always a
  /// supplementary call layered on top of the already-shown local results,
  /// never a replacement for them.
  Future<List<SearchResult>> searchRemote(
    final String query,
    final List<SearchResult> localResults,
  ) async {
    final String? cityId = _dataset.activeCityId;
    if (cityId == null || holdingsApi == null) return const <SearchResult>[];
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return const <SearchResult>[];

    final ({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})
        rows = await holdingsApi!.searchRemote(cityId: cityId, query: trimmed);

    final List<Parcel> remoteParcels = <Parcel>[
      for (final Map<String, dynamic> row in rows.holdings) holdingRowToParcel(row),
      for (final Map<String, dynamic> row in rows.addedHoldings) addedHoldingRowToParcel(row),
    ];
    if (remoteParcels.isEmpty) return const <SearchResult>[];

    final Set<String> localKeys =
        localResults.map((final SearchResult r) => r.groupKey).toSet();

    final Map<String, Parcel> bestByHolding = <String, Parcel>{};
    for (final Parcel p in remoteParcels) {
      if (localKeys.contains(p.groupKey)) continue;
      bestByHolding.putIfAbsent(p.groupKey, () => p);
    }

    return <SearchResult>[
      for (final Parcel p in bestByHolding.values)
        SearchResult(
          holdingId: p.holdingId,
          groupKey: p.groupKey,
          holderName: p.holderName,
          parcelCount: 1,
          score: 0,
          completedCount: p.completedAt != null ? 1 : 0,
          isFieldAdded: p.isFieldAdded,
        ),
    ];
  }

  /// Resolves creator emails for the given `Parcel.createdBy` uuids
  /// (`REFACTOR_ROADMAP.md` Phase 11 §12) — cached in-memory for the life
  /// of the repository (city-session scoped) since a profile's email
  /// essentially never changes mid-session and this is called once per
  /// visible added-parcel badge. Returns an empty map when there's no
  /// [holdingsApi] (test/no-network mode) or nothing to resolve.
  final Map<String, String> _profileEmailCache = <String, String>{};

  Future<Map<String, String>> resolveCreatorEmails(
    final Iterable<String> createdByIds,
  ) async {
    final List<String> missing = createdByIds
        .toSet()
        .where((final String id) => !_profileEmailCache.containsKey(id))
        .toList();
    if (missing.isNotEmpty && holdingsApi != null) {
      final Map<String, String> fetched =
          await holdingsApi!.fetchProfileEmails(missing);
      _profileEmailCache.addAll(fetched);
    }
    return <String, String>{
      for (final String id in createdByIds)
        if (_profileEmailCache.containsKey(id)) id: _profileEmailCache[id]!,
    };
  }

  /// Distinct اسم الحوض values in the active dataset, sorted.
  @override
  List<String> get availableBasins =>
      _queryService.availableBasins(_dataset.parcels);

  /// Distinct-holding count per اسم الحوض — how many holdings sit in each
  /// basin, shown beside the basin filter/status views.
  @override
  Map<String, int> get basinHoldingCounts =>
      _queryService.basinHoldingCounts(_dataset.parcels);

  @override
  List<Parcel> parcelsForHolding(final String holdingId) =>
      _queryService.parcelsForHolding(_dataset.parcels, holdingId);

  @override
  Parcel? findByBorderText(final String? borderText) =>
      _queryService.findByBorderText(_dataset.borderIndex, borderText);

  /// Applies [value] to every parcel's [field], optionally scoped to
  /// [basin] (only parcels whose اسم الحوض matches).
  ///
  /// **Outbox model:** every in-scope row is applied to the local dataset
  /// immediately and one [BulkEditOperation] per row is enqueued — this no
  /// longer awaits each row's Supabase insert, so [BulkEditOutcome] means
  /// "rows queued for background sync," not "rows the server has already
  /// confirmed." A permanently-failed row surfaces later via the
  /// failed-syncs UI, not synchronously from this call.
  @override
  Future<BulkEditOutcome> bulkApplyField({
    required final BulkEditableField field,
    required final Object? value,
    final String? basin,
  }) async {
    final BulkEditResult result = _bulkEditService.apply(
      _dataset.parcels,
      field: field,
      value: value,
      basin: basin,
    );

    if (result.changedCount == 0) {
      return const BulkEditOutcome(succeeded: 0, failed: 0);
    }

    final String? cityId = _dataset.activeCityId;

    final List<Parcel> inScope = <Parcel>[];
    final List<Parcel> outOfScope = <Parcel>[];
    for (final Parcel p in result.parcels) {
      (basin == null || p.basinName == basin ? inScope : outOfScope).add(p);
    }

    // Snapshots are computed up front (keyed by id) so the enqueue loop and
    // this method's own edit-overlay bookkeeping agree on the exact same
    // payload per row.
    final Map<String, Map<String, dynamic>> snapshots = <String, Map<String, dynamic>>{
      for (final Parcel p in inScope) p.id: _dataset.editSnapshot(p),
    };

    if (_syncRunner == null || await _isOnline()) {
      // Online (or no outbox configured): awaits each row's Supabase
      // insert and reports the real per-row outcome
      // (`REFACTOR_ROADMAP.md` Phase 19) — this was already the honest
      // behavior on the no-outbox path, just not reached when a
      // `_syncRunner` was configured and the device was actually online.
      final BulkSyncResult syncResult = await _syncService.syncBulkEdit(
        parcels: inScope,
        cityId: cityId,
        snapshotForParcel: (final Parcel p) => snapshots[p.id]!,
      );

      final List<Parcel> nextInScope = <Parcel>[];
      for (final Parcel p in inScope) {
        if (!syncResult.failedIds.contains(p.id)) {
          _dataset.setEdit(p.id, snapshots[p.id]!);
          nextInScope.add(p);
        } else {
          nextInScope.add(
            _dataset.originalParcel(p.id) != null ? _dataset.applyEdit(p) : p,
          );
        }
      }
      _dataset.replaceAll(<Parcel>[...nextInScope, ...outOfScope]);
      _dataset.rebuildBorderIndex();
      if (syncResult.outcome.succeeded > 0) {
        await _dataset.persistEdits();
      }
      return syncResult.outcome;
    }

    for (final Parcel p in inScope) {
      _dataset.setEdit(p.id, snapshots[p.id]!);
    }
    _dataset.replaceAll(<Parcel>[...inScope, ...outOfScope]);
    // Defensive: no `BulkEditableField` touches حائز/مالك today, but
    // rebuilding here is O(n) same as the reassignment above and keeps
    // this repository from silently drifting out of sync if that ever
    // changes, without needing every future field to remember this rule.
    _dataset.rebuildBorderIndex();
    await _dataset.persistEdits();

    if (cityId != null) {
      for (final Parcel p in inScope) {
        _enqueue(
          BulkEditOperation(
            operationId: _uuid.v4(),
            createdAt: DateTime.now(),
            holdingId: p.id,
            cityId: cityId,
            payload: snapshots[p.id]!,
          ),
        );
      }
    }

    return BulkEditOutcome(succeeded: inScope.length, failed: 0);
  }
}
