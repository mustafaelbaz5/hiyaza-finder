import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../holdings/domain/entities/parcel.dart';
import '../../holdings/domain/services/parcel_edit_overlay.dart';
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
  /// server instead of on-device storage.
  ///
  /// Approved app-added records (`added_holdings`) aren't included yet —
  /// there's nothing to promote into them until the add-person/add-parcel
  /// flows land (APP_PLAN.md Phase 4).
  Future<List<Parcel>> downloadHoldings(final String cityId) async {
    try {
      final List<Map<String, dynamic>> holdingRows = await _client
          .from('holdings')
          .select()
          .eq('city_id', cityId)
          .eq('is_stale', false);

      final List<Map<String, dynamic>> editRows = await _client
          .from('holding_edits_latest')
          .select('holding_id, payload')
          .eq('city_id', cityId);

      final Map<String, Map<String, dynamic>> latestEditByHoldingId =
          <String, Map<String, dynamic>>{
        for (final Map<String, dynamic> row in editRows)
          row['holding_id'] as String: row['payload'] as Map<String, dynamic>,
      };

      return holdingRows.map((final Map<String, dynamic> row) {
        final Parcel base = holdingRowToParcel(row);
        return _editOverlay.apply(base, latestEditByHoldingId[base.id]);
      }).toList();
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
      );
}
