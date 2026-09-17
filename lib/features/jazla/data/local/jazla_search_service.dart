import '../../../holdings/data/local/holding_search_service.dart';
import '../../../holdings/data/model/parcel.dart';

/// A parcel-level search hit — unlike `SearchResult` (holding-grouped), each
/// [ParcelSearchResult] is one specific [Parcel], carrying whether it's
/// already claimed by another Jazla.
class ParcelSearchResult {
  const ParcelSearchResult({
    required this.parcel,
    required this.score,
    required this.isLocked,
    this.jazlaName,
  });

  final Parcel parcel;
  final int score;
  final bool isLocked;

  /// The owning Jazla's name — `null` exactly when [isLocked] is `false`.
  final String? jazlaName;
}

/// Reuses `HoldingSearchService`'s query-detection and scoring methods
/// directly, skipping its private holding-level grouping — Jazla's add-flow
/// needs individual parcel results, not one row per holding.
class JazlaSearchService {
  const JazlaSearchService({
    final HoldingSearchService searcher = const HoldingSearchService(),
  }) : _searcher = searcher;

  final HoldingSearchService _searcher;
  static const int _maxResults = 20;

  /// [jazlaNameByParcelId] is precomputed once per sheet-open by the caller
  /// (`{ for (final j in allJazlasInCity) for (final id in j.parcelIds) id:
  /// j.name }`) — an O(1) lock lookup instead of a per-result repo call.
  List<ParcelSearchResult> search(
    final List<Parcel> parcels,
    final String rawQuery,
    final Map<String, String> jazlaNameByParcelId,
  ) {
    final String query = rawQuery.trim();
    if (query.isEmpty) return const <ParcelSearchResult>[];

    final List<ScoredParcel> scored = switch (detectSearchType(query)) {
      SearchType.holdingNumber => _searcher.searchByHoldingNumber(parcels, query),
      SearchType.parcelId => _searcher.searchByParcelId(parcels, query),
      SearchType.holderName => _searcher.searchByHolderName(parcels, query),
    };

    final List<ParcelSearchResult> results = scored.map((final ScoredParcel s) {
      final String? owner = jazlaNameByParcelId[s.parcel.id];
      return ParcelSearchResult(
        parcel: s.parcel,
        score: s.score,
        isLocked: owner != null,
        jazlaName: owner,
      );
    }).toList()
      ..sort((final ParcelSearchResult a, final ParcelSearchResult b) {
        if (a.isLocked != b.isLocked) return a.isLocked ? 1 : -1;
        return b.score.compareTo(a.score);
      });

    return results.take(_maxResults).toList();
  }
}
