/// A holding-level search hit derived from one or more parcel records.
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

  final String holdingId;
  final String groupKey;
  final String? holderName;
  final int parcelCount;
  final int score;
  final int completedCount;
  final bool isFieldAdded;
}
