import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/cities/data/local/city_snapshot_cache.dart';
import 'package:hiyaza_finder/features/cities/data/model/cached_city_meta.dart';
import 'package:hiyaza_finder/features/cities/data/model/city_snapshot.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.tempDirPath);

  final String tempDirPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDirPath;
}

void main() {
  late Directory tempDir;
  late CitySnapshotCache cache;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('city_snapshot_cache_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    cache = const CitySnapshotCache();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  CitySnapshot snapshotFor(final String cityId, {final int parcelCount = 2}) {
    return CitySnapshot(
      cityId: cityId,
      cityName: 'مدينة $cityId',
      dataVersion: 3,
      downloadedAt: DateTime(2026, 1, 1),
      parcels: List<Parcel>.generate(
        parcelCount,
        (final int i) => Parcel(id: 'p$i', holdingId: '10$i'),
      ),
    );
  }

  test('listCachedCityIds is empty when nothing has been saved', () async {
    expect(await cache.listCachedCityIds(), isEmpty);
  });

  test('listCachedCityIds returns every saved city id', () async {
    await cache.save(snapshotFor('city-1'));
    await cache.save(snapshotFor('city-2'));

    final List<String> ids = await cache.listCachedCityIds();
    expect(ids, containsAll(<String>['city-1', 'city-2']));
    expect(ids, hasLength(2));
  });

  test('loadMetadata returns null for a city with no cached snapshot', () async {
    expect(await cache.loadMetadata('missing'), isNull);
  });

  test('loadMetadata summarizes a saved snapshot without full parcel mapping', () async {
    await cache.save(snapshotFor('city-1', parcelCount: 5));

    final CachedCityMeta? meta = await cache.loadMetadata('city-1');

    expect(meta, isNotNull);
    expect(meta!.cityId, 'city-1');
    expect(meta.cityName, 'مدينة city-1');
    expect(meta.dataVersion, 3);
    expect(meta.parcelsCount, 5);
    expect(meta.fileSizeBytes, greaterThan(0));
  });

  test('delete removes the cached file so load/loadMetadata see nothing', () async {
    await cache.save(snapshotFor('city-1'));
    expect(await cache.load('city-1'), isNotNull);

    await cache.delete('city-1');

    expect(await cache.load('city-1'), isNull);
    expect(await cache.loadMetadata('city-1'), isNull);
    expect(await cache.listCachedCityIds(), isEmpty);
  });

  test('delete on a city with no cached file does nothing', () async {
    await cache.delete('never-existed'); // should not throw
    expect(await cache.listCachedCityIds(), isEmpty);
  });
}
