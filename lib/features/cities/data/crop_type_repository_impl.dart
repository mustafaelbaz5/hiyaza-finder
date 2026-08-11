import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/errors/exceptions.dart';
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
      // A row that fails the write RLS policy is silently excluded from the
      // delete rather than raising an error — `.select()` after `.delete()`
      // returns the rows actually deleted, so an empty result here is the
      // only way to detect "nothing was actually removed" (e.g. an RLS
      // rejection or the row already being gone) and surface it as a real
      // failure instead of a false success that reappears on the next fetch.
      final List<Map<String, dynamic>> deleted = await _client
          .from('city_crop_types')
          .delete()
          .eq('city_id', cityId)
          .eq('crop_type', cropType)
          .select();
      if (deleted.isEmpty) {
        throw NotFoundException(
          message: 'This crop type could not be removed — it may have '
              'already been deleted, or you may not have permission.',
        );
      }
    } catch (error) {
      ErrorHandler.handleException(error);
    }
  }
}
