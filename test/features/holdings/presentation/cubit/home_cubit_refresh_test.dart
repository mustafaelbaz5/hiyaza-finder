import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/cached_city_meta.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city_snapshot.dart';
import 'package:hiyaza_finder/features/cities/domain/repositories/city_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/cubit/home_cubit.dart';

/// Covers the egress-reduction guard added to `HomeCubit.refreshActiveCity`
/// (the staleness banner's "تحديث البيانات" action and the home screen's
/// pull-to-refresh): it should skip the full `downloadCity` round-trip when
/// the server's `data_version` hasn't advanced past the active snapshot's,
/// and still re-download when it has. Before this fix it called
/// `downloadCity` unconditionally every time, which the accompanying
/// `holdings_repository_sync_now_test.dart` describes in more detail — this
/// file covers the other of the two call sites with the same bug.
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

CitySnapshot _snapshotAt(final int dataVersion) => CitySnapshot(
      cityId: 'c1',
      cityName: 'مدينة اختبار',
      dataVersion: dataVersion,
      downloadedAt: DateTime(2026),
      parcels: const <Parcel>[
        Parcel(id: 'h1', holdingId: '101', holderName: 'محمد', basinName: 'البشيط'),
      ],
    );

void main() {
  late _FakeCityRepository cityRepository;
  late HoldingsRepository holdingsRepository;
  late HomeCubit cubit;

  setUp(() {
    cityRepository = _FakeCityRepository(remoteVersion: 5);
    holdingsRepository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
    );
    cubit = HomeCubit(holdingsRepository, cityRepository);
  });

  tearDown(() {
    cubit.close();
  });

  test(
      'skips downloadCity and clears the stale flag when the server '
      'data_version has not advanced past the active snapshot', () async {
    cubit.loadFromDownloadedCity(_snapshotAt(5));
    cityRepository.remoteVersion = 5; // unchanged

    await cubit.refreshActiveCity();

    expect(
      cityRepository.downloadCityCallCount,
      0,
      reason: 'remote version equals the active snapshot\'s — a full '
          're-download would just re-transfer identical data',
    );
    expect(cubit.state.isCityDataStale, isFalse);
  });

  test(
      'still re-downloads when the server data_version has advanced past '
      'the active snapshot', () async {
    cubit.loadFromDownloadedCity(_snapshotAt(5));
    cityRepository.remoteVersion = 6; // a real server-side change happened

    await cubit.refreshActiveCity();

    expect(
      cityRepository.downloadCityCallCount,
      1,
      reason: 'a genuine remote change must still trigger a re-download',
    );
    expect(cubit.state.isCityDataStale, isFalse);
  });

  test('does nothing when no city is active', () async {
    await cubit.refreshActiveCity();
    expect(cityRepository.downloadCityCallCount, 0);
  });
}
