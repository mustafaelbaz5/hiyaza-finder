import '../../domain/entities/parcel.dart';
import 'arabic_normalizer.dart';

class SearchResult {
  const SearchResult({
    required this.holdingId,
    required this.groupKey,
    required this.holderName,
    required this.parcelCount,
    required this.score,
    this.reviewedCount = 0,
  });

  /// رقم الحيازة as shown to the user — may be a shared placeholder
  /// ("" or "-") for a pending record. Display only; use [groupKey] to
  /// look up this holding's parcels.
  final String holdingId;

  /// What actually identifies this result — see `Parcel.groupKey`.
  final String groupKey;
  final String? holderName;
  final int parcelCount;
  final int score;

  /// How many of this group's parcels are reviewed. `parcelCount ==
  /// reviewedCount` means "fully done", `0` means "not started", anything
  /// between is "partial".
  final int reviewedCount;
}

/// Numeric queries rank by holding-ID prefix/contains match. Text queries
/// rank holder names in two tiers against the normalized name:
///
/// - Tier 1 ("starts with", high priority): the full name starts with the
///   query, or — a more precise variant of the same rule — an individual
///   word inside the name starts with it (so typing "م" ranks "علي محمود"
///   here too, not just "محمد علي").
/// - Tier 2 ("contains", low priority): the query appears anywhere else in
///   the name (e.g. mid-word). These still show up, just below every Tier 1
///   result, instead of a bare `.contains()` mixing them in at random.
///
/// No fuzzy/typo-tolerant scoring — matches are exact substring checks on
/// normalized text. Results are grouped by holding ID (best score kept)
/// and capped at 10.
class HoldingSearchService {
  const HoldingSearchService();

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// Tier 1 — query matches from the very start of the full name.
  static const int _fullNameStartScore = 100;

  /// Tier 1 — query matches the start of an inner word only.
  static const int _wordStartScore = 80;

  /// Tier 2 — query appears somewhere in the name, but not at a word start.
  static const int _containsScore = 40;

  static const int _maxResults = 10;

  List<SearchResult> search(
    final List<Parcel> parcels,
    final String rawQuery,
  ) {
    final String query = rawQuery.trim();
    if (query.isEmpty) return const <SearchResult>[];

    // Parcel-id matching always runs alongside whichever of the two
    // existing branches applies — a query can't be reliably classified as
    // "id-shaped" up front (a uuid fragment like "123" is digits-only, and
    // a fragment like "a3f" is neither digits-only nor a plausible name
    // token), so instead of a three-way mutually-exclusive dispatch, id
    // results are simply concatenated in; _groupAndRank already collapses
    // to the best score per groupKey regardless of which matcher produced
    // it.
    final List<_ScoredParcel> scored = <_ScoredParcel>[
      ...(_digitsOnly.hasMatch(query)
          ? _scoreByHoldingId(parcels, query)
          : _scoreByHolderName(parcels, query)),
      ..._scoreByParcelId(parcels, query),
    ];

    final Map<String, int> parcelCountsByHolding = <String, int>{};
    final Map<String, int> reviewedCountsByHolding = <String, int>{};
    for (final Parcel parcel in parcels) {
      parcelCountsByHolding[parcel.groupKey] =
          (parcelCountsByHolding[parcel.groupKey] ?? 0) + 1;
      if (parcel.reviewed) {
        reviewedCountsByHolding[parcel.groupKey] =
            (reviewedCountsByHolding[parcel.groupKey] ?? 0) + 1;
      }
    }

    return _groupAndRank(scored, parcelCountsByHolding, reviewedCountsByHolding);
  }

  List<_ScoredParcel> _scoreByHoldingId(
    final List<Parcel> parcels,
    final String query,
  ) {
    final List<_ScoredParcel> results = <_ScoredParcel>[];
    for (final Parcel parcel in parcels) {
      final String id = parcel.holdingId;
      if (id.startsWith(query)) {
        results.add(_ScoredParcel(parcel, 100));
      } else if (id.contains(query)) {
        results.add(_ScoredParcel(parcel, 50));
      }
    }
    return results;
  }

  /// Matches [Parcel.id] (the stable cross-system uuid) case-insensitively
  /// — lets a field worker paste/type a full or partial parcel id (copied
  /// from the detail card's ID chip) to jump straight to it.
  List<_ScoredParcel> _scoreByParcelId(
    final List<Parcel> parcels,
    final String query,
  ) {
    final String q = query.toLowerCase();
    final List<_ScoredParcel> results = <_ScoredParcel>[];
    for (final Parcel parcel in parcels) {
      final String id = parcel.id.toLowerCase();
      if (id.startsWith(q)) {
        results.add(_ScoredParcel(parcel, 100));
      } else if (id.contains(q)) {
        results.add(_ScoredParcel(parcel, 50));
      }
    }
    return results;
  }

  List<_ScoredParcel> _scoreByHolderName(
    final List<Parcel> parcels,
    final String query,
  ) {
    final String normalizedQuery = ArabicNormalizer.normalizeForSearch(query);
    if (normalizedQuery.isEmpty) return const <_ScoredParcel>[];

    final List<_ScoredParcel> results = <_ScoredParcel>[];
    for (final Parcel parcel in parcels) {
      final String? holderName = parcel.holderName;
      if (holderName == null || holderName.isEmpty) continue;

      final int? score = _matchScore(normalizedQuery, holderName);
      if (score != null) results.add(_ScoredParcel(parcel, score));
    }
    return results;
  }

  /// `null` when [holderName] doesn't match [normalizedQuery] at all.
  int? _matchScore(final String normalizedQuery, final String holderName) {
    final String normalizedName = ArabicNormalizer.normalizeForSearch(
      holderName,
    );

    if (normalizedName.startsWith(normalizedQuery)) {
      return _fullNameStartScore;
    }

    final bool matchesAWord = normalizedName
        .split(' ')
        .any((final String word) => word.startsWith(normalizedQuery));
    if (matchesAWord) return _wordStartScore;

    if (normalizedName.contains(normalizedQuery)) return _containsScore;

    return null;
  }

  List<SearchResult> _groupAndRank(
    final List<_ScoredParcel> scored,
    final Map<String, int> parcelCountsByHolding,
    final Map<String, int> reviewedCountsByHolding,
  ) {
    final Map<String, _ScoredParcel> bestByHolding = <String, _ScoredParcel>{};
    for (final _ScoredParcel entry in scored) {
      final String key = entry.parcel.groupKey;
      final _ScoredParcel? existing = bestByHolding[key];
      if (existing == null || entry.score > existing.score) {
        bestByHolding[key] = entry;
      }
    }

    final List<SearchResult> results = bestByHolding.values
        .map(
          (final _ScoredParcel entry) => SearchResult(
            holdingId: entry.parcel.holdingId,
            groupKey: entry.parcel.groupKey,
            holderName: entry.parcel.holderName,
            parcelCount: parcelCountsByHolding[entry.parcel.groupKey] ?? 1,
            score: entry.score,
            reviewedCount: reviewedCountsByHolding[entry.parcel.groupKey] ?? 0,
          ),
        )
        .toList()
      ..sort(
        (final SearchResult a, final SearchResult b) =>
            b.score.compareTo(a.score),
      );

    return results.take(_maxResults).toList();
  }
}

class _ScoredParcel {
  const _ScoredParcel(this.parcel, this.score);

  final Parcel parcel;
  final int score;
}
