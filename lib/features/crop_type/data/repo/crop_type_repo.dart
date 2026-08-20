abstract class CropTypeRepo {
  /// Current crop types for [cityId] — falls back to
  /// `Parcel.cropTypeOptions` if the city has no custom list saved yet.
  Future<List<String>> fetchCropTypes(final String cityId);

  /// Appends [cropType] to [cityId]'s list. No-ops if it already exists.
  Future<void> addCropType(final String cityId, final String cropType);

  /// Removes [cropType] from [cityId]'s list — only edits the option list,
  /// never touches existing `Parcel.cropType` values already saved with it.
  Future<void> removeCropType(final String cityId, final String cropType);
}
