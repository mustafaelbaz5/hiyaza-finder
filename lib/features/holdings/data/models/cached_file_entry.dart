/// Metadata for one previously-loaded workbook kept in the on-device file
/// history, so the user can switch back to it without re-picking it.
class CachedFileEntry {
  const CachedFileEntry({
    required this.fileName,
    required this.filePath,
    required this.cachedAt,
    required this.holdingCount,
  });

  final String fileName;
  final String filePath;
  final DateTime cachedAt;
  final int holdingCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fileName': fileName,
        'filePath': filePath,
        'cachedAt': cachedAt.toIso8601String(),
        'holdingCount': holdingCount,
      };

  factory CachedFileEntry.fromJson(final Map<String, dynamic> json) =>
      CachedFileEntry(
        fileName: json['fileName'] as String,
        filePath: json['filePath'] as String,
        cachedAt: DateTime.parse(json['cachedAt'] as String),
        holdingCount: json['holdingCount'] as int,
      );
}
