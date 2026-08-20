import 'dart:convert';

import '../../../holdings/data/local/parcel_edit_overlay.dart';
import '../../../holdings/data/local/parcel_mapper.dart';
import '../../../holdings/data/model/parcel.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/error_handler.dart';
import '../model/association_type.dart';
import '../model/city.dart';

/// HTTP-only replacement for the old `supabase_flutter`-based data source —
/// hits the same PostgREST endpoints directly (`/rest/v1/<table>`) with the
/// public anon key, since no writes ever happen from this app. The four
/// queries and the edit-overlay/count merge in [downloadHoldings] mirror
/// exactly what the Supabase SDK version did; only the transport changed.
class CityRemoteDataSource {
  CityRemoteDataSource(
    this._client, {
    final ParcelEditOverlay editOverlay = const ParcelEditOverlay(),
  }) : _editOverlay = editOverlay;

  final http.Client _client;
  final ParcelEditOverlay _editOverlay;

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

  /// Pages through a PostgREST query via `Range`/`Content-Range` until a
  /// page comes back shorter than [_pageSize] — same "no more rows" signal
  /// the Supabase client used, just driven by raw HTTP headers now.
  Future<List<Map<String, dynamic>>> _fetchAllPages(
    final String table,
    final Map<String, String> query,
  ) async {
    final List<Map<String, dynamic>> all = <Map<String, dynamic>>[];
    int from = 0;
    while (true) {
      final http.Response response = await _client.get(
        _restUri(table, query),
        headers: <String, String>{
          ..._headers,
          'Range': '$from-${from + _pageSize - 1}',
        },
      );
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
      <String, String>{'status': 'eq.published', 'order': 'name'},
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

  /// Fetches every non-stale holding for [cityId] and overlays the latest
  /// saved correction (if any) from `holding_edits_latest`, merges in every
  /// approved `added_holdings` record not yet promoted, and populates
  /// `Parcel.holdingsCount` from `city_top_holders` — same merge this app
  /// always did, just sourced over plain HTTP now.
  Future<List<Parcel>> downloadHoldings(final String cityId) async {
    final List<Map<String, dynamic>> holdingRows = await _fetchAllPages(
      'holdings',
      <String, String>{'city_id': 'eq.$cityId', 'is_stale': 'eq.false'},
    );

    final List<Map<String, dynamic>> editRows = await _fetchAllPages(
      'holding_edits_latest',
      <String, String>{
        'city_id': 'eq.$cityId',
        'select': 'holding_id,payload',
      },
    );

    final List<Map<String, dynamic>> addedRows = await _fetchAllPages(
      'added_holdings',
      <String, String>{'city_id': 'eq.$cityId', 'status': 'eq.approved'},
    );

    final List<Map<String, dynamic>> countRows = await _fetchAllPages(
      'city_top_holders',
      <String, String>{
        'city_id': 'eq.$cityId',
        'select': 'holding_id_number,holdings_count',
      },
    );

    final Map<String, int> countByHoldingId = <String, int>{
      for (final Map<String, dynamic> row in countRows)
        if (row['holding_id_number'] != null)
          row['holding_id_number'] as String: row['holdings_count'] as int,
    };

    final Map<String, Map<String, dynamic>> latestEditByHoldingId =
        <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> row in editRows)
        row['holding_id'] as String: row['payload'] as Map<String, dynamic>,
    };
    final Map<String, String> personIdByHoldingId = <String, String>{
      for (final Map<String, dynamic> row in addedRows)
        if (row['promoted_holding_id'] != null && row['person_id'] != null)
          row['promoted_holding_id'] as String: row['person_id'] as String,
    };
    final Map<String, String> sourceAddedHoldingIdByHoldingId =
        <String, String>{
      for (final Map<String, dynamic> row in addedRows)
        if (row['promoted_holding_id'] != null && row['id'] != null)
          row['promoted_holding_id'] as String: row['id'] as String,
    };

    final List<Parcel> holdings =
        holdingRows.map((final Map<String, dynamic> row) {
      final Parcel base = holdingRowToParcel(row);
      final Parcel withCount = base.copyWith(
        holdingsCount: countByHoldingId[base.holdingId],
        personId: base.personId ?? personIdByHoldingId[base.id],
        sourceAddedHoldingId: base.sourceAddedHoldingId ??
            sourceAddedHoldingIdByHoldingId[base.id],
      );
      return _editOverlay.apply(withCount, latestEditByHoldingId[base.id]);
    }).toList();

    final List<Parcel> added = addedRows
        .where((final Map<String, dynamic> row) =>
            row['promoted_holding_id'] == null)
        .map(addedHoldingRowToParcel)
        .toList();

    return <Parcel>[...holdings, ...added];
  }

  City _cityFromRow(final Map<String, dynamic> row) => City(
        id: row['id'] as String,
        name: row['name'] as String,
        directorate: row['directorate'] as String?,
        administration: row['administration'] as String?,
        status: cityStatusFromString(row['status'] as String),
        dataVersion: row['data_version'] as int,
        associationType:
            associationTypeFromString(row['association_type'] as String?),
        associationSubtype: row['association_subtype'] as String?,
        code: row['code'] as String?,
      );
}
