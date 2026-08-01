import '../../logic/services/holding_search_service.dart';
import '../entities/parcel.dart';

/// Pure read-side queries over an in-memory parcel list: search, basin
/// aggregation, and holding lookup. Extracted from `HoldingsRepository` so
/// this logic is testable without any I/O and reusable regardless of where
/// the parcels came from (Excel today, Supabase later).
class ParcelQueryService {
  const ParcelQueryService({
    final HoldingSearchService searchService = const HoldingSearchService(),
  }) : _searchService = searchService;

  final HoldingSearchService _searchService;

  /// Searches within [basin] (اسم الحوض) if given, otherwise the whole
  /// dataset — narrowing the scope keeps matching fast on large files.
  List<SearchResult> search(
    final List<Parcel> parcels,
    final String query, {
    final String? basin,
  }) {
    final List<Parcel> scope = basin == null
        ? parcels
        : parcels.where((final Parcel p) => p.basinName == basin).toList();
    return _searchService.search(scope, query);
  }

  /// Distinct اسم الحوض values in [parcels], sorted.
  List<String> availableBasins(final List<Parcel> parcels) {
    final Set<String> basins = <String>{};
    for (final Parcel p in parcels) {
      final String? name = p.basinName?.trim();
      if (name != null && name.isNotEmpty) basins.add(name);
    }
    final List<String> sorted = basins.toList()..sort();
    return sorted;
  }

  /// Distinct-holding count per اسم الحوض — how many holdings sit in each
  /// basin, shown beside the basin filter/status views. Counts by
  /// `groupKey`, not `holdingId` — several pending (not-yet-numbered) new
  /// people can share the same blank/"-" رقم الحيازة, and counting by the
  /// raw id would collapse them into one.
  Map<String, int> basinHoldingCounts(final List<Parcel> parcels) {
    final Map<String, Set<String>> holdingsByBasin = <String, Set<String>>{};
    for (final Parcel p in parcels) {
      final String? name = p.basinName?.trim();
      if (name == null || name.isEmpty) continue;
      holdingsByBasin.putIfAbsent(name, () => <String>{}).add(p.groupKey);
    }
    return <String, int>{
      for (final MapEntry<String, Set<String>> e in holdingsByBasin.entries)
        e.key: e.value.length,
    };
  }

  /// [groupKey] is `Parcel.groupKey` (from a `SearchResult`), not the raw
  /// رقم الحيازة — see that getter's doc for why: several pending records
  /// can share the same placeholder id and must not be merged together.
  List<Parcel> parcelsForHolding(
    final List<Parcel> parcels,
    final String groupKey,
  ) =>
      parcels.where((final Parcel p) => p.groupKey == groupKey).toList();
}
