import '../../../../core/data/local_json_store.dart';
import '../../../../core/data/storage_keys.dart';
import '../../../../core/storage/key_value_store.dart';
import '../model/association_type.dart';
import '../model/city.dart';

/// Stores the last published-city catalog so the picker can open instantly
/// and remain useful when the device is offline.
class CityCatalogStore {
  const CityCatalogStore({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  final KeyValueStore _store;
  LocalJsonStore get _json => LocalJsonStore(_store);

  Future<List<City>> load() async {
    final List<dynamic>? rows =
        await _json.readList(StorageKeys.publishedCityCatalog);
    if (rows == null) return const <City>[];
    return rows
        .map((final dynamic row) => _fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(final List<City> cities) async {
    await _json.write(
      StorageKeys.publishedCityCatalog,
      cities.map(_toJson).toList(),
    );
  }

  Map<String, dynamic> _toJson(final City city) => <String, dynamic>{
        'id': city.id,
        'name': city.name,
        'directorate': city.directorate,
        'administration': city.administration,
        'isPublished': city.isPublished,
        'dataVersion': city.dataVersion,
        'associationType': city.associationType == null
            ? null
            : associationTypeToString(city.associationType!),
        'associationSubtype': city.associationSubtype,
      };

  City _fromJson(final Map<String, dynamic> json) => City(
        id: json['id'] as String,
        name: json['name'] as String,
        directorate: json['directorate'] as String?,
        administration: json['administration'] as String?,
        isPublished: json['isPublished'] as bool? ?? true,
        dataVersion: json['dataVersion'] as int? ?? 0,
        associationType:
            associationTypeFromString(json['associationType'] as String?),
        associationSubtype: json['associationSubtype'] as String?,
      );
}
