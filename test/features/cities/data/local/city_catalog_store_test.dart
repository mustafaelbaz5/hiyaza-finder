import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/cities/data/local/city_catalog_store.dart';
import 'package:hiyaza_finder/features/cities/data/model/association_type.dart';
import 'package:hiyaza_finder/features/cities/data/model/city.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(final String key) async => values[key];

  @override
  Future<void> remove(final String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(final String key, final String value) async {
    values[key] = value;
  }
}

void main() {
  test('persists and restores the published city catalog', () async {
    final CityCatalogStore store = CityCatalogStore(store: _MemoryStore());
    const City city = City(
      id: 'city-1',
      name: 'الدير',
      associationType: AssociationType.agriculturalCredit,
      isPublished: true,
      dataVersion: 4,
    );

    await store.save(const <City>[city]);

    final List<City> restored = await store.load();
    expect(restored, hasLength(1));
    expect(restored.single.id, city.id);
    expect(restored.single.dataVersion, 4);
  });
}
