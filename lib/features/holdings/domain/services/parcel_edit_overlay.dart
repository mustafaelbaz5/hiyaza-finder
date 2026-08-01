import '../entities/parcel.dart';

/// Pure merge logic for the "original parcel + saved edit snapshot" overlay
/// pattern: given a freshly parsed [Parcel] and a saved
/// [Parcel.toEditableJson] snapshot, produces the parcel with corrections
/// applied. Extracted from `HoldingsRepository` so the merge itself has no
/// dependency on where the snapshot came from (local storage today, a
/// `holding_edits` row later).
class ParcelEditOverlay {
  const ParcelEditOverlay();

  /// Returns [original] unchanged when [edits] has no entry for its id.
  Parcel apply(final Parcel original, final Map<String, dynamic>? edits) {
    if (edits == null) return original;
    return Parcel.fromEditableJson(original, edits);
  }

  Map<String, dynamic> snapshot(final Parcel parcel) => parcel.toEditableJson();
}
