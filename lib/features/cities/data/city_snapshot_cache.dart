import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../holdings/domain/entities/parcel.dart';
import '../domain/entities/association_type.dart';
import '../domain/entities/cached_city_meta.dart';
import '../domain/entities/city_snapshot.dart';

/// Persists a downloaded [CitySnapshot] to a JSON file in app storage —
/// a city's holdings (thousands of rows) are too big for
/// `SharedPreferences`, unlike the small per-parcel edit overlay that
/// already lives there via `ParcelEditsStore`.
class CitySnapshotCache {
  const CitySnapshotCache();

  static const String _dirName = 'city_snapshots';

  Future<File> _fileFor(final String cityId) async {
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docsDir.path}/$_dirName');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/$cityId.json');
  }

  Future<void> save(final CitySnapshot snapshot) async {
    final File file = await _fileFor(snapshot.cityId);
    final Map<String, dynamic> json = <String, dynamic>{
      'cityId': snapshot.cityId,
      'cityName': snapshot.cityName,
      'dataVersion': snapshot.dataVersion,
      'downloadedAt': snapshot.downloadedAt.toIso8601String(),
      'parcels': snapshot.parcels.map((final Parcel p) => p.toJson()).toList(),
      'directorate': snapshot.directorate,
      'administration': snapshot.administration,
      'associationType': snapshot.associationType == null
          ? null
          : associationTypeToString(snapshot.associationType!),
      'associationSubtype': snapshot.associationSubtype,
    };
    await file.writeAsString(jsonEncode(json), flush: true);
  }

  Future<CitySnapshot?> load(final String cityId) async {
    final File file = await _fileFor(cityId);
    if (!file.existsSync()) return null;

    final Map<String, dynamic> json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return CitySnapshot(
      cityId: json['cityId'] as String,
      cityName: json['cityName'] as String,
      dataVersion: json['dataVersion'] as int,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      parcels: (json['parcels'] as List<dynamic>)
          .map((final dynamic e) => Parcel.fromJson(e as Map<String, dynamic>))
          .toList(),
      directorate: json['directorate'] as String?,
      administration: json['administration'] as String?,
      // Absent in snapshots cached before this field existed (including the
      // old `cityType`-based ones) — `associationTypeFromString(null)`
      // gracefully falls back to `null` (type not known), same as the old
      // detection-miss fallback did.
      associationType:
          associationTypeFromString(json['associationType'] as String?),
      associationSubtype: json['associationSubtype'] as String?,
    );
  }

  /// The city ids with a snapshot currently on disk — cheap, no JSON
  /// parsing (just lists filenames in the cache directory).
  Future<List<String>> listCachedCityIds() async {
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docsDir.path}/$_dirName');
    if (!dir.existsSync()) return const <String>[];

    return dir
        .listSync()
        .whereType<File>()
        .where((final File f) => f.path.endsWith('.json'))
        .map((final File f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toList();
  }

  /// A cached snapshot's summary — city name/version/download time, row
  /// count, and file size — without mapping every row through
  /// `Parcel.fromJson` the way [load] does. Used by the "manage downloaded
  /// cities" screen, where only the summary is shown.
  Future<CachedCityMeta?> loadMetadata(final String cityId) async {
    final File file = await _fileFor(cityId);
    if (!file.existsSync()) return null;

    final int sizeBytes = file.statSync().size;
    final Map<String, dynamic> json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return CachedCityMeta(
      cityId: json['cityId'] as String,
      cityName: json['cityName'] as String,
      dataVersion: json['dataVersion'] as int,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      parcelsCount: (json['parcels'] as List<dynamic>).length,
      fileSizeBytes: sizeBytes,
    );
  }

  /// Deletes [cityId]'s cached snapshot file, if any. Does nothing if it's
  /// already gone.
  Future<void> delete(final String cityId) async {
    final File file = await _fileFor(cityId);
    if (file.existsSync()) await file.delete();
  }
}
