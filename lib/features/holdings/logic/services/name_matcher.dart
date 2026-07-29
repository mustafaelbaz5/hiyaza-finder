import 'package:fuzzywuzzy/fuzzywuzzy.dart' as fuzzy;

import 'arabic_normalizer.dart';

/// Single source of truth for "how similar are these two Arabic names",
/// shared by search and border navigation so both get the same robustness
/// (previously each ran its own copy of this logic).
class NameMatcher {
  const NameMatcher._();

  /// Scores [query] against [candidate] after loosely normalizing both
  /// (see [ArabicNormalizer.normalizeForMatching]). Combines `weightedRatio`
  /// (robust to typos/reordering across the whole string) with
  /// `partialRatio` (rewards when a short query is essentially a
  /// substring of a longer candidate, so partial names match without
  /// requiring the full name) and keeps the higher of the two.
  static int score(final String query, final String candidate) {
    final String nq = ArabicNormalizer.normalizeForMatching(query);
    final String nc = ArabicNormalizer.normalizeForMatching(candidate);
    if (nq.isEmpty || nc.isEmpty) return 0;

    final int weighted = fuzzy.weightedRatio(nq, nc);
    final int partial = fuzzy.partialRatio(nq, nc);
    return weighted > partial ? weighted : partial;
  }
}
