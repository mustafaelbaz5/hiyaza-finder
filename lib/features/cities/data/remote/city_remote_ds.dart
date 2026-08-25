import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../holdings/data/local/parcel_mapper.dart';
import '../../../holdings/data/model/parcel.dart';
import '../model/association_type.dart';
import '../model/basin.dart';
import '../model/city.dart';

/// A city's parcels + basins, downloaded together in one round-trip.
class CityDownloadResult {
  const CityDownloadResult({required this.parcels, required this.basins});

  final List<Parcel> parcels;
  final List<Basin> basins;
}

/// HTTP-only data source — hits the PostgREST endpoints (`/rest/v1/<table>`)
/// directly with the public anon key, since no writes ever happen from this
/// app. Backend schema: `cities` (one row per جمعية), `basins` (one row per
/// حوض, pre-aggregated `parcel_count`/totals), `parcels` (one row per قطعة,
/// FK'd to both). All field-worker-entered data (owner_name, crop_type,
/// notes, toggles, completion) lives purely in the local edit overlay —
/// none of it is a remote column.
class CityRemoteDataSource {
  CityRemoteDataSource(this._client);

  final http.Client _client;

  static const int _pageSize = 1000;

  Uri _restUri(final String table, final Map<String, String> query) {
    return Uri.parse('${AppConfig.supabaseUrl}/rest/v1/$table').replace(
      queryParameters: query,
    );
  }

  Map<String, String> get _headers => <String, String>{
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
      };

  /// Pages through a PostgREST query via the `Range` request header until a
  /// page comes back shorter than [_pageSize] — the only reliable
  /// "no more rows" signal PostgREST gives without a separate count request.
  Future<List<Map<String, dynamic>>> _fetchAllPages(
    final String table,
    final Map<String, String> query,
  ) async {
    final List<Map<String, dynamic>> all = <Map<String, dynamic>>[];
    int from = 0;
    while (true) {
      final http.Response response;
      try {
        response = await _client.get(
          _restUri(table, query),
          headers: <String, String>{
            ..._headers,
            'Range': '$from-${from + _pageSize - 1}',
          },
        );
      } catch (error) {
        // A raw SocketException/ClientException from `http` (no route/DNS
        // failure, connection refused) never reaches ErrorHandler on its
        // own — this call site is the only place it's thrown, so it must
        // be caught and reclassified here rather than left to escape as a
        // raw exception all the way to the UI.
        ErrorHandler.handleException(error);
      }
      if (response.statusCode >= 400) {
        ErrorHandler.handleException(
          'GET $table failed: ${response.statusCode} ${response.body}',
        );
      }
      final List<dynamic> page = jsonDecode(response.body) as List<dynamic>;
      all.addAll(page.cast<Map<String, dynamic>>());
      if (page.length < _pageSize) break;
      from += _pageSize;
    }
    return all;
  }

  Future<List<City>> listPublishedCities() async {
    final List<Map<String, dynamic>> rows = await _fetchAllPages(
      'cities',
      <String, String>{'is_published': 'eq.true', 'order': 'name'},
    );
    return rows.map(_cityFromRow).toList();
  }

  Future<int> remoteDataVersion(final String cityId) async {
    final List<Map<String, dynamic>> rows = await _fetchAllPages(
      'cities',
      <String, String>{'id': 'eq.$cityId', 'select': 'data_version'},
    );
    return rows.single['data_version'] as int;
  }

  /// Fetches every parcel for [cityId] — a flat `parcels` table, no
  /// added/edits/counts tables to merge in on this schema; every parcel row
  /// already carries its own `parcel_count_in_holding`.
  Future<List<Parcel>> downloadHoldings(final String cityId) async {
    final List<Map<String, dynamic>> rows = await _fetchAllPages(
      'parcels',
      <String, String>{'city_id': 'eq.$cityId'},
    );
    return rows.map(parcelRowToParcel).toList();
  }

  /// Fetches [cityId]'s parcels and basins in the same download — basins
  /// are a small, pre-aggregated table (one row per حوض), so pulling both
  /// together costs one extra request, not a separate download flow.
  Future<CityDownloadResult> downloadCityData(final String cityId) async {
    final List<Parcel> parcels = await downloadHoldings(cityId);
    final List<Map<String, dynamic>> basinRows = await _fetchAllPages(
      'basins',
      <String, String>{'city_id': 'eq.$cityId'},
    );
    return CityDownloadResult(
      parcels: parcels,
      basins: basinRows.map(basinRowToBasin).toList(),
    );
  }

  City _cityFromRow(final Map<String, dynamic> row) => City(
        id: row['id'] as String,
        name: row['name'] as String,
        directorate: row['directorate'] as String?,
        administration: row['administration'] as String?,
        isPublished: row['is_published'] as bool,
        dataVersion: row['data_version'] as int,
        associationType:
            associationTypeFromString(row['association_type'] as String?),
        associationSubtype: row['association_subtype'] as String?,
      );
}
