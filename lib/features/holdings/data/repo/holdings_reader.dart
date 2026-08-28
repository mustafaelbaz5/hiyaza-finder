import '../local/holding_search_service.dart';
import '../model/basin_progress.dart';
import '../model/parcel.dart';

/// Read-side contract for holdings data, kept separate from
/// [HoldingsWriter] (interface segregation) — a widget that only searches
/// and displays shouldn't depend on write methods it never calls.
///
/// Deliberately scoped to operations that survive the move to Supabase
/// (search, basin aggregation, holding lookup). Excel-era concerns like
/// file picking and load history are not part of this contract — they are
/// retired once the city-download flow lands (see `APP_PLAN.md` Phase 5).
abstract class HoldingsReader {
  List<Parcel> get parcels;

  List<SearchResult> search(final String query, {final String? basin});

  /// Every distinct holding, city-wide, unfiltered by basin — Home's flat
  /// list (APP_CLAUDE.md § 9.1).
  List<SearchResult> get allHoldings;

  List<String> get availableBasins;

  Map<String, int> get basinHoldingCounts;

  /// One [BasinProgress] per basin in the active dataset, sorted by name —
  /// backs the basin-first home screen.
  List<BasinProgress> get basinSummaries;

  List<Parcel> parcelsForHolding(final String holdingId);

  /// The `groupKey` immediately before/after [currentGroupKey] within
  /// [basinName], ordered the same way `BasinScreen` lists holdings —
  /// backs Detail screen's Previous/Next. `null` at either end, or if
  /// [currentGroupKey] isn't found in [basinName].
  String? adjacentHoldingGroupKey(
    final String basinName,
    final String currentGroupKey, {
    required final bool next,
  });

  /// Resolves a الحدود (border) cell's free text to the holding it refers
  /// to, if any currently-loaded حائز/مالك matches it exactly. `null` when
  /// the text is blank, a non-person boundary (طريق/مصرف/...), or doesn't
  /// match anyone in the active dataset.
  Parcel? findByBorderText(final String? borderText);
}
