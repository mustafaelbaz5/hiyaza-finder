import '../../data/models/parcel.dart';
import 'arabic_normalizer.dart';

class SearchResult {
  const SearchResult({
    required this.holdingId,
    required this.holderName,
    required this.parcelCount,
    required this.score,
  });

  final String holdingId;
  final String? holderName;
  final int parcelCount;
  final int score;
}

/// Numeric queries rank by holding-ID prefix/contains match. Text queries
/// match by `startsWith` against the normalized holder name — either the
/// whole name starts with the query, or any individual word in the name
/// does (so typing "م" matches "علي محمود" as well as "محمد علي") — no
/// fuzzy/typo-tolerant scoring, so results are exact-prefix only. Results
/// are grouped by holding ID (best score kept) and capped at 10.
class HoldingSearchService {
  const HoldingSearchService();

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// Score for a query matching from the very start of the full name.
  static const int _fullNameStartScore = 100;

  /// Score for a query matching the start of an inner word only.
  static const int _wordStartScore = 80;

  static const int _maxResults = 10;

  List<SearchResult> search(
    final List<Parcel> parcels,
    final String rawQuery,
  ) {
    final String query = rawQuery.trim();
    if (query.isEmpty) return const <SearchResult>[];

    final List<_ScoredParcel> scored = _digitsOnly.hasMatch(query)
        ? _scoreByHoldingId(parcels, query)
        : _scoreByHolderName(parcels, query);

    final Map<String, int> parcelCountsByHolding = <String, int>{};
    for (final Parcel parcel in parcels) {
      parcelCountsByHolding[parcel.holdingId] =
          (parcelCountsByHolding[parcel.holdingId] ?? 0) + 1;
    }

    return _groupAndRank(scored, parcelCountsByHolding);
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

    return null;
  }

  List<SearchResult> _groupAndRank(
    final List<_ScoredParcel> scored,
    final Map<String, int> parcelCountsByHolding,
  ) {
    final Map<String, _ScoredParcel> bestByHolding = <String, _ScoredParcel>{};
    for (final _ScoredParcel entry in scored) {
      final String id = entry.parcel.holdingId;
      final _ScoredParcel? existing = bestByHolding[id];
      if (existing == null || entry.score > existing.score) {
        bestByHolding[id] = entry;
      }
    }

    final List<SearchResult> results =
        bestByHolding.values
            .map(
              (final _ScoredParcel entry) => SearchResult(
                holdingId: entry.parcel.holdingId,
                holderName: entry.parcel.holderName,
                parcelCount: parcelCountsByHolding[entry.parcel.holdingId] ?? 1,
                score: entry.score,
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
