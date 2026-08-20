
import 'package:hiyaza_finder/features/holdings/data/local/holding_search_service.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

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

  List<String> get availableBasins;

  Map<String, int> get basinHoldingCounts;

  List<Parcel> parcelsForHolding(final String holdingId);

  /// Resolves a الحدود (border) cell's free text to the holding it refers
  /// to, if any currently-loaded حائز/مالك matches it exactly. `null` when
  /// the text is blank, a non-person boundary (طريق/مصرف/...), or doesn't
  /// match anyone in the active dataset.
  Parcel? findByBorderText(final String? borderText);
}
