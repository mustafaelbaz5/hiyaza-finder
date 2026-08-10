import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../domain/repositories/crop_type_repository.dart';

/// The only file that queries `city_crop_types` directly. Every write is
/// online-required — this is an admin-ish maintenance action, not part of
/// the offline field-write path `HoldingsRepository` owns.
class CropTypeRepositoryImpl implements CropTypeRepository {
  CropTypeRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<String>> fetchCropTypes(final String cityId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('city_crop_types')
          .select('crop_type')
          .eq('city_id', cityId)
          .order('sort_order');
      return rows.map((final Map<String, dynamic> row) => row['crop_type'] as String).toList();
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  @override
  Future<void> addCropType(final String cityId, final String cropType) async {
    try {
      await _client.from('city_crop_types').upsert(
        <String, dynamic>{'city_id': cityId, 'crop_type': cropType},
        onConflict: 'city_id,crop_type',
        ignoreDuplicates: true,
      );
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }

  @override
  Future<void> removeCropType(final String cityId, final String cropType) async {
    try {
      await _client
          .from('city_crop_types')
          .delete()
          .eq('city_id', cityId)
          .eq('crop_type', cropType);
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }
}
