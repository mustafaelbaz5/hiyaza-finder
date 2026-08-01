import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/cities/data/city_repository_impl.dart';
import 'package:hiyaza_finder/features/cities/data/city_snapshot_cache.dart';
import 'package:hiyaza_finder/features/cities/data/supabase_city_data_source.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/cached_city_meta.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city_snapshot.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.tempDirPath);

  final String tempDirPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDirPath;
}

class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> getString(final String key) async => _store[key];

  @override
  Future<void> remove(final String key) async => _store.remove(key);

  @override
  Future<void> setString(final String key, final String value) async {
    _store[key] = value;
  }
}

void main() {
  late Directory tempDir;
  late _InMemoryKeyValueStore keyValueStore;
  late CityRepositoryImpl repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('city_repository_impl_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    keyValueStore = _InMemoryKeyValueStore();
    repository = CityRepositoryImpl(
      // Never exercised by the methods under test (listCachedCities /
      // deleteCachedCity work purely off the local cache + key-value
      // store) — a real client is constructed without hitting the
      // network unless a method on it is actually called.
      dataSource: SupabaseCityDataSource(SupabaseClient('https://x.supabase.co', 'anon-key')),
      cache: const CitySnapshotCache(),
      keyValueStore: keyValueStore,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('listCachedCities returns a summary for every cached city', () async {
    await const CitySnapshotCache().save(
      CitySnapshot(
        cityId: 'city-1',
        cityName: 'مدينة',
        dataVersion: 1,
        downloadedAt: DateTime(2026),
        parcels: const <Parcel>[Parcel(id: 'p1', holdingId: '1')],
      ),
    );

    final List<CachedCityMeta> cities = await repository.listCachedCities();

    expect(cities, hasLength(1));
    expect(cities.single.cityId, 'city-1');
  });

  test('deleteCachedCity clears active_city_id when it matches the deleted city',
      () async {
    await keyValueStore.setString('active_city_id', 'city-1');
    await const CitySnapshotCache().save(
      CitySnapshot(
        cityId: 'city-1',
        cityName: 'مدينة',
        dataVersion: 1,
        downloadedAt: DateTime(2026),
        parcels: const <Parcel>[],
      ),
    );

    await repository.deleteCachedCity('city-1');

    expect(await keyValueStore.getString('active_city_id'), isNull);
    expect(await repository.loadActiveCachedSnapshot(), isNull);
  });

  test('deleteCachedCity leaves active_city_id untouched for a different city',
      () async {
    await keyValueStore.setString('active_city_id', 'city-1');
    await const CitySnapshotCache().save(
      CitySnapshot(
        cityId: 'city-2',
        cityName: 'مدينة أخرى',
        dataVersion: 1,
        downloadedAt: DateTime(2026),
        parcels: const <Parcel>[],
      ),
    );

    await repository.deleteCachedCity('city-2');

    expect(await keyValueStore.getString('active_city_id'), 'city-1');
  });
}
