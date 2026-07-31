import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/errors/exceptions.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city_snapshot.dart';
import 'package:hiyaza_finder/features/cities/domain/repositories/city_repository.dart';
import 'package:hiyaza_finder/features/cities/presentation/cubit/city_picker_cubit.dart';
import 'package:hiyaza_finder/features/cities/presentation/cubit/city_state.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';

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
  Object? downloadError;
  Object? listError;

  @override
  Future<List<City>> listPublishedCities() async {
    if (listError != null) throw listError!;
    return const <City>[
      City(id: 'c1', name: 'مدينة اختبار', status: CityStatus.published, dataVersion: 1),
    ];
  }

  @override
  Future<CitySnapshot> downloadCity(final City city) async {
    if (downloadError != null) throw downloadError!;
    return CitySnapshot(
      cityId: city.id,
      cityName: city.name,
      dataVersion: city.dataVersion,
      downloadedAt: DateTime(2026),
      parcels: const <Parcel>[
        Parcel(id: 'h1', holdingId: '101', holderName: 'محمد', basinName: 'البشيط'),
      ],
    );
  }

  @override
  Future<CitySnapshot?> loadActiveCachedSnapshot() async => null;

  @override
  Future<int> remoteDataVersion(final String cityId) async => 1;
}

void main() {
  late _FakeCityRepository cityRepository;
  late HoldingsRepository holdingsRepository;

  setUp(() {
    cityRepository = _FakeCityRepository();
    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    holdingsRepository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
    );
  });

  test('loadCities emits loaded with the fetched cities', () async {
    final CityPickerCubit cubit = CityPickerCubit(cityRepository, holdingsRepository);
    await cubit.loadCities();

    expect(cubit.state.status, CityPickerStatus.loaded);
    expect(cubit.state.cities, hasLength(1));
    expect(cubit.state.cities.first.name, 'مدينة اختبار');
  });

  test('loadCities emits error on failure', () async {
    cityRepository.listError = UnauthorizedException(message: 'nope');
    final CityPickerCubit cubit = CityPickerCubit(cityRepository, holdingsRepository);
    await cubit.loadCities();

    expect(cubit.state.status, CityPickerStatus.error);
    expect(cubit.state.errorMessage, 'nope');
  });

  test('downloadAndActivate returns the snapshot and populates HoldingsRepository',
      () async {
    final CityPickerCubit cubit = CityPickerCubit(cityRepository, holdingsRepository);
    const City city =
        City(id: 'c1', name: 'مدينة اختبار', status: CityStatus.published, dataVersion: 1);

    final CitySnapshot? snapshot = await cubit.downloadAndActivate(city);

    expect(snapshot, isNotNull);
    expect(snapshot!.cityId, 'c1');
    expect(holdingsRepository.parcels, hasLength(1));
    expect(holdingsRepository.parcels.first.holdingId, '101');
  });

  test('downloadAndActivate returns null and surfaces the error on failure',
      () async {
    cityRepository.downloadError = UnauthorizedException(message: 'denied');
    final CityPickerCubit cubit = CityPickerCubit(cityRepository, holdingsRepository);
    const City city =
        City(id: 'c1', name: 'مدينة اختبار', status: CityStatus.published, dataVersion: 1);

    final CitySnapshot? snapshot = await cubit.downloadAndActivate(city);

    expect(snapshot, isNull);
    expect(cubit.state.status, CityPickerStatus.loaded);
    expect(cubit.state.errorMessage, 'denied');
  });
}
