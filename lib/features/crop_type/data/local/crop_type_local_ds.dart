import 'dart:convert';

import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

import '../../../../core/storage/key_value_store.dart';


/// Per-city نوع الزرع option list, stored on-device only — replaces the old
/// `city_crop_types` Supabase table now that the app never writes to the
/// server. Falls back to [Parcel.cropTypeOptions] wherever a city has no
/// custom list saved yet.
class CropTypeLocalDataSource {
  CropTypeLocalDataSource(this._store);

  final KeyValueStore _store;

  static String _key(final String cityId) => 'crop_types::$cityId';

  Future<List<String>> fetchCropTypes(final String cityId) async {
    final String? raw = await _store.getString(_key(cityId));
    if (raw == null) return Parcel.cropTypeOptions;
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<String>();
  }

  Future<void> addCropType(final String cityId, final String cropType) async {
    final List<String> current = await fetchCropTypes(cityId);
    if (current.contains(cropType)) return;
    await _store.setString(
      _key(cityId),
      jsonEncode(<String>[...current, cropType]),
    );
  }

  Future<void> removeCropType(
    final String cityId,
    final String cropType,
  ) async {
    final List<String> current = await fetchCropTypes(cityId);
    await _store.setString(
      _key(cityId),
      jsonEncode(current.where((final String c) => c != cropType).toList()),
    );
  }
}
