import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/cached_city_meta.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city_snapshot.dart';
import 'package:hiyaza_finder/features/cities/domain/repositories/city_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';

/// Covers the egress-reduction guard added to `HoldingsRepository.syncNow`:
/// a pull-to-refresh should skip the full `downloadCity` round-trip when the
/// server's `data_version` hasn't advanced past what's already loaded, and
/// should still re-download when it has. Before this fix `syncNow` called
/// `downloadCity` unconditionally on every call, which was a significant
/// driver of this project's Supabase egress usage (re-transferring an
/// entire city's holdings on every pull-to-refresh regardless of whether
/// anything had actually changed).
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

class _FakeCityRepository implements CityRepository {
  _FakeCityRepository({required this.remoteVersion});

  int remoteVersion;
  int downloadCityCallCount = 0;

  @override
  Future<int> remoteDataVersion(final String cityId) async => remoteVersion;

  @override
  Future<CitySnapshot> downloadCity(final City city) async {
    downloadCityCallCount++;
    return CitySnapshot(
      cityId: city.id,
      cityName: city.name,
      dataVersion: remoteVersion,
      downloadedAt: DateTime(2026),
      parcels: const <Parcel>[
        Parcel(id: 'h1', holdingId: '101', holderName: 'محمد', basinName: 'البشيط'),
      ],
    );
  }

  @override
  Future<List<City>> listPublishedCities() async => const <City>[];

  @override
  Future<CitySnapshot?> loadActiveCachedSnapshot() async => null;

  @override
  Future<List<CachedCityMeta>> listCachedCities() async => const <CachedCityMeta>[];

  @override
  Future<void> deleteCachedCity(final String cityId) async {}

  @override
  Future<City> fetchCity(final String cityId) => throw UnimplementedError();

  @override
  Future<void> updateCityCode(final String cityId, final String? code) =>
      throw UnimplementedError();
}

void main() {
  late _FakeCityRepository cityRepository;
  late HoldingsRepository holdingsRepository;

  setUp(() async {
    cityRepository = _FakeCityRepository(remoteVersion: 1);
    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    holdingsRepository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
    );
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<CityRepository>(cityRepository);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  test('does nothing when no city is active', () async {
    await holdingsRepository.syncNow();
    expect(cityRepository.downloadCityCallCount, 0);
  });

  test(
      'skips downloadCity when the server data_version has not advanced '
      'past the version the active city was loaded at', () async {
    await holdingsRepository.loadParcelsForCity(
      'c1',
      const <Parcel>[
        Parcel(id: 'h1', holdingId: '101', holderName: 'محمد', basinName: 'البشيط'),
      ],
      cityName: 'مدينة اختبار',
      dataVersion: 5,
    );
    cityRepository.remoteVersion = 5; // unchanged since load

    await holdingsRepository.syncNow();

    expect(
      cityRepository.downloadCityCallCount,
      0,
      reason: 'remote version equals the locally loaded version — a full '
          're-download would just re-transfer identical data',
    );
  });

  test(
      'still re-downloads when the server data_version has advanced past '
      'the locally loaded version', () async {
    await holdingsRepository.loadParcelsForCity(
      'c1',
      const <Parcel>[
        Parcel(id: 'h1', holdingId: '101', holderName: 'محمد', basinName: 'البشيط'),
      ],
      cityName: 'مدينة اختبار',
      dataVersion: 5,
    );
    cityRepository.remoteVersion = 6; // a real server-side change happened

    await holdingsRepository.syncNow();

    expect(
      cityRepository.downloadCityCallCount,
      1,
      reason: 'a genuine remote change must still trigger a re-download',
    );
  });

  test(
      'downloads unconditionally when no local data_version has been '
      'recorded yet (loadParcelsForCity called without one)', () async {
    await holdingsRepository.loadParcelsForCity(
      'c1',
      const <Parcel>[
        Parcel(id: 'h1', holdingId: '101', holderName: 'محمد', basinName: 'البشيط'),
      ],
      cityName: 'مدينة اختبار',
      // no dataVersion passed — simulates a caller that never threaded it
      // through, which must fail open (still sync) rather than silently
      // never refreshing again.
    );
    cityRepository.remoteVersion = 1;

    await holdingsRepository.syncNow();

    expect(cityRepository.downloadCityCallCount, 1);
  });
}
