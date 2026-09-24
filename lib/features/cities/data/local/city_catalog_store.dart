import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';
import '../model/association_type.dart';
import '../model/city.dart';

/// Stores the last published-city catalog so the picker can open instantly
/// and remain useful when the device is offline.
class CityCatalogStore {
  const CityCatalogStore({
    final KeyValueStore store = const SharedPreferencesKeyValueStore(),
  }) : _store = store;

  static const String _key = 'published_city_catalog';

  final KeyValueStore _store;

  Future<List<City>> load() async {
    final String? raw = await _store.getString(_key);
    if (raw == null || raw.isEmpty) return const <City>[];
    final List<dynamic> rows = jsonDecode(raw) as List<dynamic>;
    return rows
        .map((final dynamic row) => _fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(final List<City> cities) async {
    await _store.setString(
      _key,
      jsonEncode(cities.map(_toJson).toList()),
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
