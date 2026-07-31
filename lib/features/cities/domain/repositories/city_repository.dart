import '../entities/city.dart';
import '../entities/city_snapshot.dart';

abstract class CityRepository {
  /// Cities the app is allowed to offer for download — `published` only,
  /// enforced both by this query and by RLS server-side.
  Future<List<City>> listPublishedCities();

  /// Fetches a city's holdings (+ latest edits overlay) from the server,
  /// caches the result locally, and marks it the active city. Overwrites
  /// any previously cached snapshot for this city.
  Future<CitySnapshot> downloadCity(final City city);

  /// The most recently downloaded city's snapshot, read from the local
  /// cache — `null` if nothing has ever been downloaded (or the cache was
  /// cleared). Works fully offline.
  Future<CitySnapshot?> loadActiveCachedSnapshot();

  /// The server's current `data_version` for [cityId] — used to compare
  /// against a cached snapshot's stored version.
  Future<int> remoteDataVersion(final String cityId);
}
