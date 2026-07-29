import '../../data/models/parcel.dart';
import 'name_matcher.dart';

/// Mirrors `_serialize_border`: resolves a border's free-text holder name to
/// the best-matching parcel's holding ID via the same fuzzy match used for
/// search, or `null` if nothing scores high enough to be confident.
class BorderNavigatorService {
  const BorderNavigatorService();

  static const int _fuzzyThreshold = 75;

  /// Resolves a border's free-text holder name to a neighboring holding ID.
  ///
  /// Neighbors are, by definition, adjacent parcels — so when [basinName] is
  /// given (the current parcel's اسم الحوض), matching is scoped to parcels in
  /// that same basin first. This avoids picking an unrelated same-named (or
  /// similarly-named) holder elsewhere in the dataset, which previously could
  /// send a tap to the wrong person. Falls back to the full dataset only if
  /// nothing confident is found within the basin.
  String? resolve(
    final String borderText,
    final List<Parcel> parcels, {
    final String? basinName,
  }) {
    final String trimmed = borderText.trim();
    if (trimmed.isEmpty) return null;

    if (basinName != null && basinName.trim().isNotEmpty) {
      final List<Parcel> sameBasin = parcels
          .where((final Parcel p) => p.basinName == basinName)
          .toList();
      final String? scoped = _bestMatch(trimmed, sameBasin);
      if (scoped != null) return scoped;
    }

    return _bestMatch(trimmed, parcels);
  }

  String? _bestMatch(final String trimmedQuery, final List<Parcel> parcels) {
    String? bestHoldingId;
    int bestScore = -1;
    for (final Parcel parcel in parcels) {
      final String? holderName = parcel.holderName;
      if (holderName == null || holderName.isEmpty) continue;
      final int score = NameMatcher.score(trimmedQuery, holderName);
      if (score > bestScore) {
        bestScore = score;
        bestHoldingId = parcel.holdingId;
      }
    }

    if (bestHoldingId == null || bestScore < _fuzzyThreshold) return null;
    return bestHoldingId;
  }
}
