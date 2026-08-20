import 'arabic_normalizer.dart';
import 'holding_search_service.dart';
import '../model/parcel.dart';
import 'border_name_index.dart';

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

  /// Resolves free-text الحدود (border) text — e.g. "ورثة محمد علي" — to the
  /// holding it refers to, so the compass can offer "go see this person's
  /// data" instead of leaving it as dead text. Looks up [index] (an O(1)
  /// hash lookup built once per dataset load — see [BorderNameIndex]) rather
  /// than scanning the dataset: this is called on every الحدود cell render,
  /// up to 4× per parcel card, so it must never re-scan or re-normalize the
  /// whole city's names per call.
  ///
  /// The border columns are unstructured text typed by whoever filled the
  /// original register (APP_PLAN.md § 4, columns I–L) — there is no id or
  /// foreign key linking a border to another row, only a name that may or
  /// may not match another حائز/مالك in this same city. Matching is
  /// deliberately **exact** (after Arabic normalization only — no fuzzy
  /// substring/word scoring like [HoldingSearchService]) because a wrong
  /// guess here means silently navigating the field worker to the wrong
  /// person's land, which is worse than not offering navigation at all. When
  /// a name is ambiguous (matches more than one holding), [index] resolves
  /// it deterministically — see [BorderNameIndex.build]'s doc for the exact
  /// tie-break rule.
  ///
  /// Returns `null` if [borderText] is blank, is a non-name placeholder
  /// (e.g. "طريق"/"مصرف"/"ترعة" — public/infrastructure boundaries, not
  /// people), or doesn't exactly match any حائز/مالك currently loaded.
  Parcel? findByBorderText(
    final BorderNameIndex index,
    final String? borderText,
  ) {
    final String? normalized = _normalizedBorderName(borderText);
    if (normalized == null) return null;
    return index.lookup(normalized);
  }

  /// Border text that clearly isn't a person's name — public/infrastructure
  /// boundaries that appear verbatim across many original registers.
  /// Excluding them up front avoids even attempting (and failing) a name
  /// match for the common case, and avoids a false "no data" snackbar
  /// reading like an error when the border was never a person to begin with.
  static const Set<String> _nonPersonBorderTerms = <String>{
    'طريق',
    'مصرف',
    'ترعة',
    'زمام',
    'مسقى',
    'شارع',
    'نهر',
    'بحر',
  };

  String? _normalizedBorderName(final String? borderText) {
    final String? trimmed = borderText?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == '-') return null;

    final String normalized = ArabicNormalizer.normalize(trimmed);
    if (_nonPersonBorderTerms
        .any((final String term) => normalized.contains(term))) {
      return null;
    }

    return normalized;
  }
}
