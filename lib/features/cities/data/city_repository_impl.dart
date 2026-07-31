import '../../../core/storage/key_value_store.dart';
import '../domain/entities/city.dart';
import '../domain/entities/city_snapshot.dart';
import '../domain/repositories/city_repository.dart';
import 'city_snapshot_cache.dart';
import 'supabase_city_data_source.dart';

class CityRepositoryImpl implements CityRepository {
  CityRepositoryImpl({
    required final SupabaseCityDataSource dataSource,
    required final CitySnapshotCache cache,
    required final KeyValueStore keyValueStore,
  })  : _dataSource = dataSource,
        _cache = cache,
        _keyValueStore = keyValueStore;

  static const String _activeCityIdKey = 'active_city_id';

  final SupabaseCityDataSource _dataSource;
  final CitySnapshotCache _cache;
  final KeyValueStore _keyValueStore;

  @override
  Future<List<City>> listPublishedCities() => _dataSource.listPublishedCities();

  @override
  Future<CitySnapshot> downloadCity(final City city) async {
    final parcels = await _dataSource.downloadHoldings(city.id);
    final CitySnapshot snapshot = CitySnapshot(
      cityId: city.id,
      cityName: city.name,
      dataVersion: city.dataVersion,
      downloadedAt: DateTime.now(),
      parcels: parcels,
    );
    await _cache.save(snapshot);
    await _keyValueStore.setString(_activeCityIdKey, city.id);
    return snapshot;
  }

  @override
  Future<CitySnapshot?> loadActiveCachedSnapshot() async {
    final String? cityId = await _keyValueStore.getString(_activeCityIdKey);
    if (cityId == null) return null;
    return _cache.load(cityId);
  }

  @override
  Future<int> remoteDataVersion(final String cityId) =>
      _dataSource.remoteDataVersion(cityId);
}
