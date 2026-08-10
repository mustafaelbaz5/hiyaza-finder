/// Per-city نوع الزرع option list (`city_crop_types` table) — lets an
/// admin/editor manage the crop-type choices offered to field workers on a
/// per-city basis from the "أدوات المدينة" -> "أنواع الزرع" screen. Falls
/// back to [Parcel.cropTypeOptions] anywhere a city has none yet (see
/// `crop_type_picker.dart`), so rollout to existing cities is never a
/// blocking migration.
abstract class CropTypeRepository {
  /// Current crop types for [cityId], in [sort_order]. Requires network —
  /// this is an admin-ish action, not part of the offline field-write path.
  Future<List<String>> fetchCropTypes(final String cityId);

  /// Appends [cropType] to [cityId]'s list. No-ops if it already exists
  /// (`city_crop_types` has a `unique (city_id, crop_type)` constraint).
  Future<void> addCropType(final String cityId, final String cropType);

  /// Removes [cropType] from [cityId]'s list — only edits the option list,
  /// never touches existing `Parcel.cropType` values already saved with it.
  Future<void> removeCropType(final String cityId, final String cropType);
}
