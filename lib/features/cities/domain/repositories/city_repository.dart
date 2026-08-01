import '../entities/cached_city_meta.dart';
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

  /// Summaries of every city with a snapshot currently on disk — a field
  /// worker may have downloaded (and left behind) more than one over time
  /// even though only one is ever "active".
  Future<List<CachedCityMeta>> listCachedCities();

  /// Deletes [cityId]'s local snapshot only — server data is untouched.
  /// If [cityId] is the active city, also clears the active-city marker
  /// so the app doesn't think a deleted city is still loaded.
  Future<void> deleteCachedCity(final String cityId);
}
