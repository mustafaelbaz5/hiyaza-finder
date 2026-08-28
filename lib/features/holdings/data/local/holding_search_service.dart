import '../model/parcel.dart';
import 'arabic_normalizer.dart';

class SearchResult {
  const SearchResult({
    required this.holdingId,
    required this.groupKey,
    required this.holderName,
    required this.parcelCount,
    required this.score,
    this.completedCount = 0,
    this.isFieldAdded = false,
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

  /// How many of this group's parcels are field-worker-completed
  /// (`Parcel.completedAt` non-null). `parcelCount == completedCount` means
  /// "fully done", `0` means "not started", anything between is "partial".
  final int completedCount;

  /// Whether the best-scoring parcel behind this result was field-created
  /// (`Parcel.isFieldAdded`). Used as a same-score tiebreaker so freshly
  /// added records surface ahead of imported ones — there's no creation
  /// timestamp on [Parcel] to sort by directly, so this is the closest
  /// signal available client-side.
  final bool isFieldAdded;
}

/// Which of the three search modes a query is classified as — determined
/// purely from the query's shape, never from a user-facing toggle.
enum SearchType { holdingNumber, parcelId, holderName }

/// Every character an all-digits input can be made of — Western 0-9 plus
/// Arabic-Indic ٠-٩, so a field worker typing on an Arabic keyboard's digit
/// row still hits the holding-number path.
final RegExp _allDigits = RegExp(r'^[\d٠-٩]+$');

/// A hex string (a UUID fragment, with or without dashes) at least 8
/// characters long — long enough that a short numeric-looking token (e.g.
/// "12345") doesn't get misclassified as a parcel-id fragment purely
/// because its digits happen to also be valid hex.
final RegExp _hexFragment = RegExp(r'^[0-9a-fA-F-]{8,}$');

SearchType detectSearchType(final String query) {
  final String trimmed = query.trim();
  if (_allDigits.hasMatch(trimmed)) return SearchType.holdingNumber;
  if (_hexFragment.hasMatch(trimmed)) return SearchType.parcelId;
  return SearchType.holderName;
}

/// Maps Arabic-Indic digits (٠-٩) to their Western equivalents so a holding
/// number typed on an Arabic keyboard still matches one stored/typed with
/// Western digits, and vice versa.
String _normalizeDigits(final String value) {
  const String arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  final StringBuffer buffer = StringBuffer();
  for (final int codeUnit in value.codeUnits) {
    final String char = String.fromCharCode(codeUnit);
    final int arabicIndex = arabicIndic.indexOf(char);
    buffer.write(arabicIndex >= 0 ? arabicIndex.toString() : char);
  }
  return buffer.toString();
}

/// Strips leading zeros so "007" and "7" match the same holding — holding
/// numbers are opaque strings everywhere else in the app, but a leading
/// zero is a formatting artifact a field worker shouldn't have to type
/// exactly to find a record. Never strips down to an empty string (a
/// literal "0"/"00" normalizes to "0", not "").
String _normalizeHoldingNumber(final String value) {
  final String digits = _normalizeDigits(value.trim());
  final String stripped = digits.replaceFirst(RegExp(r'^0+(?=.)'), '');
  return stripped;
}

/// Numeric queries match رقم الحيازة by **exact match only** — typing "8"
/// finds the holding whose number *is* "8", never one that merely contains
/// or starts with an "8" (e.g. "80" or "18"). Text queries rank holder
/// names in two tiers against the normalized name:
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

  /// Exact holding-number match score — there is only one tier for this
  /// search type, unlike holder-name search's two.
  static const int _holdingNumberScore = 100;

  /// Parcel-id search tiers.
  static const int _parcelIdStartScore = 100;
  static const int _parcelIdContainsScore = 50;

  /// Holder-name search tiers.
  /// Highest possible word-position priority the scoring below converts
  /// to a score — comfortably above any realistic name's word count, so
  /// `_priorityScore` never produces a negative score.
  static const int _maxNameWords = 20;

  static const int _maxResults = 10;

  List<SearchResult> search(
    final List<Parcel> parcels,
    final String rawQuery,
  ) {
    final String query = rawQuery.trim();
    if (query.isEmpty) return const <SearchResult>[];

    final List<ScoredParcel> scored = switch (detectSearchType(query)) {
      SearchType.holdingNumber => searchByHoldingNumber(parcels, query),
      SearchType.parcelId => searchByParcelId(parcels, query),
      SearchType.holderName => searchByHolderName(parcels, query),
    };

    final Map<String, int> parcelCountsByHolding = <String, int>{};
    final Map<String, int> completedCountsByHolding = <String, int>{};
    for (final Parcel parcel in parcels) {
      parcelCountsByHolding[parcel.groupKey] =
          (parcelCountsByHolding[parcel.groupKey] ?? 0) + 1;
      if (parcel.completedAt != null) {
        completedCountsByHolding[parcel.groupKey] =
            (completedCountsByHolding[parcel.groupKey] ?? 0) + 1;
      }
    }

    return _groupAndRank(scored, parcelCountsByHolding, completedCountsByHolding);
  }

  /// EXACT MATCH only, leading-zero-insensitive — see [_normalizeHoldingNumber].
  List<ScoredParcel> searchByHoldingNumber(
    final List<Parcel> parcels,
    final String query,
  ) {
    final String normalizedQuery = _normalizeHoldingNumber(query);
    final List<ScoredParcel> results = <ScoredParcel>[];
    for (final Parcel parcel in parcels) {
      if (_normalizeHoldingNumber(parcel.holdingId) == normalizedQuery) {
        results.add(ScoredParcel(parcel, _holdingNumberScore));
      }
    }
    return results;
  }

  /// Matches [Parcel.id] (the stable cross-system uuid) case-insensitively,
  /// starts-with ranked above contains-anywhere — lets a field worker
  /// paste/type a full or partial parcel id (copied from the detail card's
  /// ID chip) to jump straight to it.
  List<ScoredParcel> searchByParcelId(
    final List<Parcel> parcels,
    final String query,
  ) {
    final String q = query.toLowerCase();
    final List<ScoredParcel> results = <ScoredParcel>[];
    for (final Parcel parcel in parcels) {
      final String id = parcel.id.toLowerCase();
      if (id.startsWith(q)) {
        results.add(ScoredParcel(parcel, _parcelIdStartScore));
      } else if (id.contains(q)) {
        results.add(ScoredParcel(parcel, _parcelIdContainsScore));
      }
    }
    return results;
  }

  List<ScoredParcel> searchByHolderName(
    final List<Parcel> parcels,
    final String query,
  ) {
    final String normalizedQuery = ArabicNormalizer.normalizeForSearch(query);
    if (normalizedQuery.isEmpty) return const <ScoredParcel>[];

    final List<ScoredParcel> results = <ScoredParcel>[];
    for (final Parcel parcel in parcels) {
      final String? holderName = parcel.holderName;
      if (holderName == null || holderName.isEmpty) continue;

      final int? score = _matchScore(normalizedQuery, holderName);
      if (score != null) results.add(ScoredParcel(parcel, score));
    }
    return results;
  }

  /// startsWith against each word of the name in turn, first match wins —
  /// `null` when no word starts with [normalizedQuery] at all (no
  /// contains-anywhere fallback, per APP_UPDATES_CLAUDE.md § 7.2). The
  /// matching word's position becomes its priority (0 = first word/highest
  /// priority); converted here to a score so lower priority sorts first
  /// under [ScoredParcel]'s "higher score wins" convention shared with
  /// every other search mode.
  int? _matchScore(final String normalizedQuery, final String holderName) {
    final String normalizedName = ArabicNormalizer.normalizeForSearch(
      holderName,
    );
    final List<String> words = normalizedName.split(' ');

    for (int i = 0; i < words.length; i++) {
      final String fromHere = words.sublist(i).join(' ');
      if (fromHere.startsWith(normalizedQuery)) return _maxNameWords - i;
    }
    return null;
  }

  List<SearchResult> _groupAndRank(
    final List<ScoredParcel> scored,
    final Map<String, int> parcelCountsByHolding,
    final Map<String, int> completedCountsByHolding,
  ) {
    final Map<String, ScoredParcel> bestByHolding = <String, ScoredParcel>{};
    for (final ScoredParcel entry in scored) {
      final String key = entry.parcel.groupKey;
      final ScoredParcel? existing = bestByHolding[key];
      if (existing == null || entry.score > existing.score) {
        bestByHolding[key] = entry;
      }
    }

    final List<SearchResult> results = bestByHolding.values
        .map(
          (final ScoredParcel entry) => SearchResult(
            holdingId: entry.parcel.holdingId,
            groupKey: entry.parcel.groupKey,
            holderName: entry.parcel.holderName,
            parcelCount: parcelCountsByHolding[entry.parcel.groupKey] ?? 1,
            score: entry.score,
            completedCount: completedCountsByHolding[entry.parcel.groupKey] ?? 0,
            isFieldAdded: entry.parcel.isFieldAdded,
          ),
        )
        .toList()
      // Field-added parcels break a same-score tie ahead of imported ones —
      // see [SearchResult.isFieldAdded]'s doc for why this (not a
      // timestamp) is the sort key.
      ..sort((final SearchResult a, final SearchResult b) {
        final int byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        if (a.isFieldAdded == b.isFieldAdded) return 0;
        return a.isFieldAdded ? -1 : 1;
      });

    return results.take(_maxResults).toList();
  }
}

class ScoredParcel {
  const ScoredParcel(this.parcel, this.score);

  final Parcel parcel;
  final int score;
}
