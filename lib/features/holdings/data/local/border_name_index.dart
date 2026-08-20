
import 'package:hiyaza_finder/features/holdings/data/local/arabic_normalizer.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

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
