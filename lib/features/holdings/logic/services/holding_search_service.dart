import '../../data/models/parcel.dart';
import 'name_matcher.dart';

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

/// Mirrors `search_holdings_use_case.py`: numeric queries rank by holding-ID
/// prefix/contains match, text queries rank by fuzzy holder-name match,
/// results are grouped by holding ID (best score kept) and capped at 10.
class HoldingSearchService {
  const HoldingSearchService();

  static final RegExp _digitsOnly = RegExp(r'^\d+$');
  static const int _fuzzyThreshold = 75;
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
    final List<_ScoredParcel> results = <_ScoredParcel>[];
    for (final Parcel parcel in parcels) {
      final String? holderName = parcel.holderName;
      if (holderName == null || holderName.isEmpty) continue;
      final int score = NameMatcher.score(query, holderName);
      if (score >= _fuzzyThreshold) {
        results.add(_ScoredParcel(parcel, score));
      }
    }
    return results;
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
