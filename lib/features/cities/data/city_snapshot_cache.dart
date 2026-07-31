import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../holdings/domain/entities/parcel.dart';
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
    );
  }
}
