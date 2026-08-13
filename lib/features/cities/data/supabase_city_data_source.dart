import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../holdings/domain/entities/parcel.dart';
import '../../holdings/domain/services/parcel_edit_overlay.dart';
import '../domain/entities/association_type.dart';
import '../domain/entities/city.dart';
import 'holding_row_mapper.dart';

/// The only file that queries `cities`/`holdings`/`holding_edits_latest`
/// directly — everything else depends on [CityRepository].
class SupabaseCityDataSource {
  SupabaseCityDataSource(
    this._client, {
    final ParcelEditOverlay editOverlay = const ParcelEditOverlay(),
  }) : _editOverlay = editOverlay;

  final SupabaseClient _client;
  final ParcelEditOverlay _editOverlay;

  /// PostgREST caps a bare `.select()` at its server-side `db-max-rows`
  /// (commonly 1000) with no error and no signal that rows were dropped —
  /// the postgrest-dart client never auto-paginates. Every query in this
  /// file must page through [_fetchAllPages] instead of awaiting a query
  /// directly, or a city with more rows than the server limit silently
  /// loses data past the cutoff.
  static const int _pageSize = 1000;

  /// Pages through [query] via `.range()` until a page comes back shorter
  /// than [_pageSize], which is the only reliable "no more rows" signal
  /// PostgREST gives without a separate count request.
  Future<List<Map<String, dynamic>>> _fetchAllPages(
    final PostgrestTransformBuilder<List<Map<String, dynamic>>> query,
  ) async {
    final List<Map<String, dynamic>> all = <Map<String, dynamic>>[];
    int from = 0;
    while (true) {
      final List<Map<String, dynamic>> page =
          await query.range(from, from + _pageSize - 1);
      all.addAll(page);
      if (page.length < _pageSize) break;
      from += _pageSize;
    }
    return all;
  }

  Future<List<City>> listPublishedCities() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('cities')
          .select()
          .eq('status', 'published')
          .order('name');
      return rows.map(_cityFromRow).toList();
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  Future<int> remoteDataVersion(final String cityId) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('cities')
          .select('data_version')
          .eq('id', cityId)
          .single();
      return row['data_version'] as int;
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  /// Fetches every non-stale holding for [cityId] and overlays the latest
  /// saved correction (if any) from `holding_edits_latest` — same merge
  /// logic the local edit overlay already uses, just sourced from the
  /// server instead of on-device storage. Also merges in every approved
  /// `added_holdings` record for the city (field-created persons/parcels
  /// the dashboard has cleared) that hasn't been promoted into `holdings`
  /// yet — `promoted_holding_id is null` excludes ones that have, so a
  /// promoted record is never counted twice once it also appears via the
  /// `holdings` query above.
  ///
  /// Also fetches holdings count per holding ID from `city_top_holders`
  /// materialized view to populate `Parcel.holdingsCount`.
  ///
  /// Note: an `added_holdings`-derived `Parcel.id` is that table's row id,
  /// not a `holdings.id` — `holding_edits.holding_id` is FK'd to
  /// `holdings(id)` only, so editing one of these records inline and
  /// syncing that edit will fail until the dashboard promotes it. Not
  /// solved here; flagged as a known follow-up.
  Future<List<Parcel>> downloadHoldings(final String cityId) async {
    try {
      final List<Map<String, dynamic>> holdingRows = await _fetchAllPages(
        _client
            .from('holdings')
            .select()
            .eq('city_id', cityId)
            .eq('is_stale', false),
      );

      final List<Map<String, dynamic>> editRows = await _fetchAllPages(
        _client
            .from('holding_edits_latest')
            .select('holding_id, payload')
            .eq('city_id', cityId),
      );

      final List<Map<String, dynamic>> addedRows = await _fetchAllPages(
        _client
            .from('added_holdings')
            .select()
            .eq('city_id', cityId)
            .eq('status', 'approved'),
      );

      final List<Map<String, dynamic>> countRows = await _fetchAllPages(
        _client
            .from('city_top_holders')
            .select('holding_id_number, holdings_count')
            .eq('city_id', cityId),
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
      final Map<String, String> personIdByHoldingId =
          <String, String>{
        for (final Map<String, dynamic> row in addedRows)
          if (row['promoted_holding_id'] != null && row['person_id'] != null)
            row['promoted_holding_id'] as String:
                row['person_id'] as String,
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
          sourceAddedHoldingId:
              base.sourceAddedHoldingId ??
                  sourceAddedHoldingIdByHoldingId[base.id],
        );
        return _editOverlay.apply(withCount, latestEditByHoldingId[base.id]);
      }).toList();

      final List<Parcel> added =
          addedRows
              .where((final Map<String, dynamic> row) =>
                  row['promoted_holding_id'] == null)
              .map(addedHoldingRowToParcel)
              .toList();

      return <Parcel>[...holdings, ...added];
    } catch (error) {
      ErrorHandler.handleException(error);
      // ignore: dead_code
      return <Parcel>[];
    }
  }

  /// Fetches a single city by id — used by "أدوات المدينة" -> كود المدينة
  /// to read the active city's current code before editing it.
  Future<City> fetchCity(final String cityId) async {
    try {
      final Map<String, dynamic> row =
          await _client.from('cities').select().eq('id', cityId).single();
      return _cityFromRow(row);
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  /// Writes [code] as `cities.code` for [cityId] — admin/editor-only per
  /// `cities_write` RLS (`20260731000009_rls_policies.sql`), same as any
  /// other `cities` column write.
  Future<void> updateCityCode(final String cityId, final String? code) async {
    try {
      await _client.from('cities').update({'code': code}).eq('id', cityId);
    } catch (error) {
      ErrorHandler.handleException(error);
    }
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
