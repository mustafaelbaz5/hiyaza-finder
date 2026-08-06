import '../services/arabic_normalizer.dart';
import '../entities/parcel.dart';

/// A precomputed, O(1)-lookup index from normalized حائز/مالك name to the
/// holding it resolves to — built once per city dataset load (see
/// [HoldingsRepository.loadParcelsForCity]) instead of scanning the whole
/// parcel list on every الحدود cell render.
///
/// **Why precompute instead of scanning on demand:** `ParcelDetailCard`
/// renders a `BorderCompass` per parcel, and each compass queries up to 4
/// border names (شمال/جنوب/شرق/غرب) on every build — including every time a
/// card scrolls into view. A naive scan re-normalizes every parcel's
/// حائز/مالك name (itself several string operations — see
/// [ArabicNormalizer.normalize]) on every one of those calls: with N
/// parcels on screen and 4 border checks each, that's up to 8×N Arabic
/// normalizations per visible card, repeated every rebuild. Building the
/// index once when the dataset loads reduces every subsequent border check
/// to a single normalization (the border text itself) plus a hash lookup —
/// independent of dataset size.
///
/// **Ambiguous names:** the border text is free-form (APP_PLAN.md § 4) and
/// nothing guarantees a اسم الحائز/اسم المالك is unique across a city — two
/// unrelated people can share a common name. When more than one *holding*
/// (distinct [Parcel.groupKey], not raw row) matches the same normalized
/// name, this index deterministically resolves to the holding with the
/// **most parcels** (i.e. the largest/most established landholding under
/// that name) — ties broken by whichever holding was encountered first in
/// [parcels]' original order, which is itself a stable, reproducible
/// ordering (server query order for downloaded data). This favors "the
/// person who's more likely who a neighbor meant" over an arbitrary pick,
/// while staying fully deterministic and offline (no interactive
/// disambiguation is attempted — see also
/// [ParcelQueryService.findByBorderText]'s doc on why a *wrong* guess is
/// treated as worse than not offering navigation at all; ambiguity here is
/// a "best effort single guess", not a fuzzy match, so it stays within that
/// same risk tolerance).
class BorderNameIndex {
  BorderNameIndex._(this._byNormalizedName);

  final Map<String, Parcel> _byNormalizedName;

  /// Builds the index from [parcels] in a single O(n) pass. Call again
  /// (replacing any previous index) whenever the active dataset changes —
  /// a fresh city load, or a local edit/add/bulk-edit that could change a
  /// حائز/مالك name or introduce a new one.
  factory BorderNameIndex.build(final List<Parcel> parcels) {
    // First pass: group every parcel by (holding, normalized name) so the
    // "most parcels under this name" tie-break can be computed per name
    // without re-scanning.
    final Map<String, Map<String, List<Parcel>>> byNameThenHolding =
        <String, Map<String, List<Parcel>>>{};

    void index(final String? rawName, final Parcel p) {
      final String? name = rawName?.trim();
      if (name == null || name.isEmpty) return;
      final String normalized = ArabicNormalizer.normalize(name);
      if (normalized.isEmpty) return;

      final Map<String, List<Parcel>> byHolding =
          byNameThenHolding.putIfAbsent(
        normalized,
        () => <String, List<Parcel>>{},
      );
      byHolding.putIfAbsent(p.groupKey, () => <Parcel>[]).add(p);
    }

    for (final Parcel p in parcels) {
      index(p.holderName, p);
      index(p.ownerName, p);
    }

    // Second pass: for each normalized name, pick the deterministic
    // representative holding (most parcels; first-encountered breaks ties)
    // and store just its first parcel as the lookup result.
    final Map<String, Parcel> byNormalizedName = <String, Parcel>{};
    for (final MapEntry<String, Map<String, List<Parcel>>> nameEntry
        in byNameThenHolding.entries) {
      Parcel? best;
      int bestCount = -1;
      for (final List<Parcel> holdingParcels in nameEntry.value.values) {
        if (holdingParcels.length > bestCount) {
          best = holdingParcels.first;
          bestCount = holdingParcels.length;
        }
      }
      if (best != null) byNormalizedName[nameEntry.key] = best;
    }

    return BorderNameIndex._(byNormalizedName);
  }

  /// An empty index — the safe default before a city has been loaded, so
  /// callers never need to null-check the index itself.
  factory BorderNameIndex.empty() => BorderNameIndex._(const <String, Parcel>{});

  /// Resolves an already-normalized name lookup key to the holding it
  /// refers to. Callers pass the raw border text through
  /// [ParcelQueryService.findByBorderText], which owns the "is this even a
  /// person's name" filtering (blank/طريق/مصرف/etc.) before consulting this
  /// index — this class only knows about names, not border-specific rules.
  Parcel? lookup(final String normalizedName) => _byNormalizedName[normalizedName];
}
