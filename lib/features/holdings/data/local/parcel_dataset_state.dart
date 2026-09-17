import 'border_name_index.dart';
import 'parcel_edit_overlay.dart';
import '../model/parcel.dart';

import '../../../cities/data/model/association_type.dart';
import '../../../cities/data/model/basin.dart';

import 'parcel_edits_store.dart';

/// Owns the active city's in-memory parcel dataset, its local edit overlay,
/// and the derived border index — the state [HoldingsRepository] used to
/// hold directly. Extracted so `HoldingsRepository` can focus on
/// orchestrating writes against this state rather than being both the state
/// holder and the orchestrator in one class.
///
/// This class does no network I/O — `HoldingsRepository` calls
/// [adopt]/[replaceAt]/etc. after a local write has already been applied.
class ParcelDatasetState {
  ParcelDatasetState({
    final ParcelEditsStore editsStore = const ParcelEditsStore(),
    final ParcelEditOverlay editOverlay = const ParcelEditOverlay(),
  })  : _editsStore = editsStore,
        _editOverlay = editOverlay;

  final ParcelEditsStore _editsStore;
  final ParcelEditOverlay _editOverlay;

  String? _activeCityId;
  String? _activeCityName;
  String? _activeDirectorate;
  String? _activeAdministration;
  AssociationType? _activeAssociationType;
  String? _activeAssociationSubtype;
  String? _activeEditsKey;

  List<Parcel> _parcels = <Parcel>[];
  List<Basin> _basins = <Basin>[];
  BorderNameIndex _borderIndex = BorderNameIndex.empty();
  Map<String, Parcel> _originalById = <String, Parcel>{};
  Map<String, Map<String, dynamic>> _edits = <String, Map<String, dynamic>>{};

  List<Parcel> get parcels => _parcels;
  List<Basin> get basins => _basins;
  BorderNameIndex get borderIndex => _borderIndex;

  String? get activeCityId => _activeCityId;
  String? get activeCityName => _activeCityName;
  String? get activeDirectorate => _activeDirectorate;
  String? get activeAdministration => _activeAdministration;
  AssociationType? get activeAssociationType => _activeAssociationType;
  String? get activeAssociationSubtype => _activeAssociationSubtype;

  /// Loads a freshly-downloaded (or cache-loaded) parcel list as the active
  /// dataset, keyed by [cityId] for local edit persistence. Local edits
  /// made after this call reapply on the next load from cache.
  Future<List<Parcel>> adopt(
    final String cityId,
    final List<Parcel> parcels, {
    final String? cityName,
    final String? directorate,
    final String? administration,
    final AssociationType? associationType,
    final String? associationSubtype,
    final List<Basin> basins = const <Basin>[],
  }) async {
    final String key = 'city::$cityId';
    _activeEditsKey = key;
    _activeCityId = cityId;
    _activeCityName = cityName ?? _activeCityName;
    _activeDirectorate = directorate ?? _activeDirectorate;
    _activeAdministration = administration ?? _activeAdministration;
    _activeAssociationType = associationType;
    _activeAssociationSubtype = associationSubtype;
    _basins = basins;
    _originalById = <String, Parcel>{
      for (final Parcel p in parcels) p.id: p,
    };
    _edits = await _editsStore.load(key);
    _parcels = parcels.map(applyEdit).toList();
    rebuildBorderIndex();
    return _parcels;
  }

  /// Rebuilds [borderIndex] from the current [parcels] — call any time
  /// [parcels] is reassigned (city load, add/edit/bulk-edit) so الحدود
  /// navigation always reflects the latest حائز/مالك names without ever
  /// scanning the dataset at lookup time.
  void rebuildBorderIndex() {
    _borderIndex = BorderNameIndex.build(_parcels);
  }

  Parcel applyEdit(final Parcel p) => _editOverlay.apply(p, _edits[p.id]);

  /// Applies an arbitrary edit-overlay [payload] (a `toEditableJson`-shaped
  /// map) onto [original] — used when the payload comes from somewhere
  /// other than this dataset's own stored edit for that parcel, e.g. a
  /// Realtime `holding_edits` INSERT event.
  Parcel applyPayload(final Parcel original, final Map<String, dynamic> payload) =>
      _editOverlay.apply(original, payload);

  Map<String, dynamic> editSnapshot(final Parcel p) => _editOverlay.snapshot(p);

  Future<void> persistEdits() async {
    if (_activeEditsKey != null) {
      await _editsStore.save(_activeEditsKey!, _edits);
    }
  }

  Map<String, dynamic>? editFor(final String id) => _edits[id];

  bool isParcelEdited(final String id) => _edits.containsKey(id);

  void setEdit(final String id, final Map<String, dynamic> snapshot) {
    _edits[id] = snapshot;
  }

  void removeEdit(final String id) {
    _edits.remove(id);
  }

  /// The pre-edit value of the parcel [id] — either the originally
  /// downloaded row, or (for a field-added record) the value at the moment
  /// it was created. `null` if [id] isn't in the active dataset.
  Parcel? originalParcel(final String id) => _originalById[id];

  void setOriginal(final String id, final Parcel parcel) {
    _originalById[id] = parcel;
  }

  void removeOriginal(final String id) {
    _originalById.remove(id);
  }

  int indexOf(final String id) =>
      _parcels.indexWhere((final Parcel p) => p.id == id);

  /// Finds the existing entry [updated] should replace, for a case
  /// [indexOf] alone can't handle: a just-promoted `holdings` row arrives
  /// with a brand-new server-generated `id`, different from the
  /// client-generated id the pre-promotion local parcel was created with
  /// (`addLocalParcel` sets that local id as its own `sourceAddedHoldingId`
  /// too). Matches, in order: the same `id` (ordinary update), the existing
  /// entry's `id` equal to [updated]'s `sourceAddedHoldingId` (the
  /// promotion case), or both sharing the same non-null
  /// `sourceAddedHoldingId` (repeat delivery of an already-promoted row).
  /// Without this, `applyRemoteChange` can't find the existing entry to
  /// replace and appends the promoted row as a second, duplicate parcel.
  int indexOfForRemoteChange(final Parcel updated) => _parcels.indexWhere(
        (final Parcel p) =>
            p.id == updated.id ||
            (updated.sourceAddedHoldingId != null &&
                p.id == updated.sourceAddedHoldingId) ||
            (p.sourceAddedHoldingId != null &&
                p.sourceAddedHoldingId == updated.sourceAddedHoldingId),
      );

  void replaceAt(final int index, final Parcel parcel) {
    _parcels[index] = parcel;
  }

  void replaceAll(final List<Parcel> parcels) {
    _parcels = parcels;
  }

  void append(final Parcel parcel) {
    _parcels = <Parcel>[..._parcels, parcel];
  }

  /// Inserts [parcel], or replaces an existing entry [indexOfForRemoteChange]
  /// finds for it (same `id`, or tied together by `sourceAddedHoldingId`) —
  /// used everywhere a new-or-promoted parcel is being added to the dataset,
  /// not just [append]'s "definitely doesn't exist yet" case. Needed because
  /// a brand-new field-added parcel that gets synchronously promoted
  /// (`added_holdings_auto_approve`) races its own Realtime echo: whichever
  /// of "the awaited HTTP response" and "the Realtime INSERT/UPDATE for the
  /// same underlying row" is processed second must reconcile with — not
  /// blindly duplicate — whatever the first one already put in [_parcels].
  /// Returns the index the parcel ended up at.
  int upsert(final Parcel parcel) {
    final int idx = indexOfForRemoteChange(parcel);
    if (idx >= 0) {
      _parcels[idx] = parcel;
    } else {
      _parcels = <Parcel>[..._parcels, parcel];
    }
    return idx >= 0 ? idx : _parcels.length - 1;
  }

}
