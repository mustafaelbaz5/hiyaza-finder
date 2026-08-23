import '../local/bulk_edit_service.dart';
import '../local/holding_search_service.dart';
import '../local/local_added_parcels_store.dart';
import '../local/local_edit_tracker.dart';
import '../local/parcel_dataset_state.dart';
import '../local/parcel_edit_overlay.dart';
import '../local/parcel_edits_store.dart';
import '../local/parcel_query_service.dart';
import '../model/basin_progress.dart';
import '../model/bulk_edit_outcome.dart';
import '../model/bulk_editable_field.dart';
import '../model/parcel.dart';
import 'holdings_reader.dart';
import 'holdings_writer.dart';
import 'package:uuid/uuid.dart';

import '../../../cities/data/model/association_type.dart';
import '../../../cities/data/model/basin.dart';

class HoldingsRepository implements HoldingsReader, HoldingsWriter {
  HoldingsRepository({
    final ParcelDatasetState? datasetState,
    final ParcelEditsStore editsStore = const ParcelEditsStore(),
    final ParcelEditOverlay editOverlay = const ParcelEditOverlay(),
    final ParcelQueryService queryService = const ParcelQueryService(),
    final BulkEditService bulkEditService = const BulkEditService(),
    final LocalAddedParcelsStore addedParcelsStore =
        const LocalAddedParcelsStore(),
    final LocalEditTracker editTracker = const LocalEditTracker(),
    final Uuid uuid = const Uuid(),
  })  : _dataset = datasetState ??
            ParcelDatasetState(editsStore: editsStore, editOverlay: editOverlay),
        _queryService = queryService,
        _bulkEditService = bulkEditService,
        _addedParcelsStore = addedParcelsStore,
        _editTracker = editTracker,
        _uuid = uuid;

  final ParcelDatasetState _dataset;
  final ParcelQueryService _queryService;
  final BulkEditService _bulkEditService;
  final LocalAddedParcelsStore _addedParcelsStore;
  final LocalEditTracker _editTracker;
  final Uuid _uuid;

  @override
  List<Parcel> get parcels => _dataset.parcels;

  /// The currently loaded city's id — `null` until a city is loaded.
  /// Exposed for city-scoped maintenance screens (e.g. per-city نوع الزرع
  /// management) that need it but aren't part of the parcel-write flow.
  String? get activeCityId => _dataset.activeCityId;
  String? get activeCityName => _dataset.activeCityName;
  String? get activeDirectorate => _dataset.activeDirectorate;
  String? get activeAdministration => _dataset.activeAdministration;

  /// Adopts a city-downloaded (or cache-loaded) parcel list as the active
  /// dataset. [associationType]/[associationSubtype] come straight from the
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
    final List<Basin> basins = const <Basin>[],
  }) async {
    final List<Parcel> result = await _dataset.adopt(
      cityId,
      parcels,
      cityName: cityName,
      directorate: directorate,
      administration: administration,
      associationType: associationType,
      associationSubtype: associationSubtype,
      basins: basins,
    );
    return result;
  }

  /// The active city's أحواض, downloaded alongside its parcels — server
  /// truth for basin code/totals, unlike [basinSummaries] (derived from
  /// [parcels], completion-focused). Empty until a city with basin data is
  /// loaded.
  List<Basin> get activeBasins => _dataset.basins;

  /// [basinName]'s [Basin] row, if the active city has one by that name —
  /// used by the basin picker (§2.3) to fill in `basin_code` automatically
  /// once the user chooses a اسم الحوض.
  Basin? basinByName(final String basinName) {
    for (final Basin b in _dataset.basins) {
      if (b.basinName == basinName) return b;
    }
    return null;
  }

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

  /// كود الجمعية — read-only, from the first parcel that has one. Shown on
  /// `CityInfoCard`; never user-entered.
  String? get defaultAssociationCode {
    for (final Parcel p in _dataset.parcels) {
      if (p.associationCode?.trim().isNotEmpty ?? false) {
        return p.associationCode;
      }
    }
    return null;
  }

  /// اسم الحائز/المالك كما يظهر في بطاقة الفلاح is not a user-entered field
  /// — it's derived from [Parcel.holderName]/[Parcel.ownerName] on every
  /// write, so the two stay in sync automatically instead of being typed
  /// twice. Applied at the [addLocalParcel]/[updateParcel] write boundary
  /// rather than inside [Parcel] itself, keeping the entity a plain data
  /// holder.
  Parcel _withDerivedFarmerCardNames(final Parcel parcel) => parcel.copyWith(
        holderNameFarmerCard: parcel.holderName,
        ownerNameFarmerCard: parcel.ownerName,
      );

  /// Adds a brand-new record created in the field — either a new person
  /// ([parentHoldingId] `null`) or a new parcel for an existing person
  /// ([parentHoldingId] set to that person's `Parcel.id`). Applied to the
  /// in-memory dataset and [LocalAddedParcelsStore] in the same call.
  /// Does nothing (returns `null`) if no city is active.
  Future<Parcel?> addLocalParcel(
    final Parcel parcel, {
    final String? parentHoldingId,
  }) async {
    final String? cityId = _dataset.activeCityId;
    if (cityId == null) return null;

    final Parcel? parent = parentHoldingId == null
        ? null
        : _dataset.parcels.cast<Parcel?>().firstWhere(
            (final Parcel? p) => p?.id == parentHoldingId,
            orElse: () => null,
          );

    // A sibling parcel added under a still-pending person (no real رقم
    // الحيازة yet) must join the *same* pending group as its parent —
    // otherwise Parcel.groupKey (keyed on each parcel's own id while
    // pending) would treat it as an unrelated new person.
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

    // Keep عدد القطع في الحيازة consistent across every parcel that shares
    // this holding — the new parcel's count already reflects the total (set
    // by the caller), so every sibling parcel is bumped to match it.
    if (parent != null) {
      _dataset.replaceAll(<Parcel>[
        for (final Parcel p in _dataset.parcels)
          if (p.groupKey == parent.groupKey)
            p.copyWith(holdingsCount: withId.holdingsCount)
          else
            p,
      ]);
    }
    _dataset.upsert(withId);
    _dataset.setOriginal(withId.id, withId);
    _dataset.rebuildBorderIndex();
    await _addedParcelsStore.save(withId, cityId);
    return withId;
  }

  /// Deletes a field-created record — drops it from the in-memory dataset
  /// and [LocalAddedParcelsStore] immediately. Returns `false` without
  /// touching local state if [id] isn't in the active dataset or isn't a
  /// field-added record — part of the authoritative `holdings` import,
  /// which this app never deletes.
  Future<bool> deleteLocalParcel(final String id) async {
    final int idx = _dataset.indexOf(id);
    if (idx < 0) return false;
    final Parcel removed = _dataset.parcels[idx];
    if (!removed.isFieldAdded) return false;

    final String? cityId = _dataset.activeCityId;

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
    if (cityId != null) await _addedParcelsStore.delete(id, cityId);
    return true;
  }

  /// Persists an edited parcel to the local edit overlay and
  /// [LocalEditTracker].
  @override
  Future<void> updateParcel(final Parcel rawEdited) async {
    final Parcel edited = _withDerivedFarmerCardNames(rawEdited);
    final int idx = _dataset.indexOf(edited.id);
    if (idx < 0) return;
    final Map<String, dynamic> snapshot = _dataset.editSnapshot(edited);
    final String? cityId = _dataset.activeCityId;

    _dataset.replaceAt(idx, edited);
    // A single-field edit can change حائز/مالك name — rebuild so a fresh
    // الحدود lookup elsewhere in the city sees the update immediately.
    _dataset.rebuildBorderIndex();
    _dataset.setEdit(edited.id, snapshot);
    await _dataset.persistEdits();
    if (cityId != null) await _editTracker.markEdited(edited.id, cityId);
  }

  /// Marks [parcelId] completed/reopened — the field-worker signal. Writes
  /// `completed_at`/`completed_by` only; never touches the edit overlay,
  /// since completion status is not part of the editable-field overlay.
  Future<Parcel?> setParcelCompleted(
    final String parcelId, {
    required final bool completed,
  }) async {
    final int idx = _dataset.indexOf(parcelId);
    if (idx < 0) return null;

    final DateTime? completedAt = completed ? DateTime.now() : null;
    final Parcel updated = _dataset.parcels[idx].copyWith(
      completedAt: completedAt,
      completedBy: null,
    );
    _dataset.replaceAt(idx, updated);
    final Parcel? original = _dataset.originalParcel(parcelId);
    _dataset.setOriginal(
      parcelId,
      (original ?? updated).copyWith(
        completedAt: updated.completedAt,
        completedBy: updated.completedBy,
      ),
    );
    return updated;
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

  @override
  List<SearchResult> get allHoldings => _queryService.allHoldings(_dataset.parcels);

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
  List<BasinProgress> get basinSummaries =>
      _queryService.basinSummaries(_dataset.parcels);

  @override
  List<Parcel> parcelsForHolding(final String holdingId) =>
      _queryService.parcelsForHolding(_dataset.parcels, holdingId);

  @override
  String? adjacentHoldingGroupKey(
    final String basinName,
    final String currentGroupKey, {
    required final bool next,
  }) =>
      _queryService.adjacentHoldingGroupKey(
        _dataset.parcels,
        basinName,
        currentGroupKey,
        next: next,
      );

  @override
  Parcel? findByBorderText(final String? borderText) =>
      _queryService.findByBorderText(_dataset.borderIndex, borderText);

  /// Applies [value] to every parcel's [field], optionally scoped to
  /// [basin] (only parcels whose اسم الحوض matches). Every in-scope row is
  /// applied to the local dataset and edit overlay immediately.
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

    for (final Parcel p in inScope) {
      _dataset.setEdit(p.id, _dataset.editSnapshot(p));
      if (cityId != null) await _editTracker.markEdited(p.id, cityId);
    }
    _dataset.replaceAll(<Parcel>[...inScope, ...outOfScope]);
    // Defensive: no `BulkEditableField` touches حائز/مالك today, but
    // rebuilding here is O(n) same as the reassignment above and keeps
    // this repository from silently drifting out of sync if that ever
    // changes, without needing every future field to remember this rule.
    _dataset.rebuildBorderIndex();
    await _dataset.persistEdits();

    return BulkEditOutcome(succeeded: inScope.length, failed: 0);
  }
}
