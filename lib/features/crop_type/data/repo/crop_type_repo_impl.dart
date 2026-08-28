import '../local/crop_type_local_ds.dart';
import 'crop_type_repo.dart';

class CropTypeRepoImpl implements CropTypeRepo {
  CropTypeRepoImpl(this._localDataSource);

  final CropTypeLocalDataSource _localDataSource;

  @override
  Future<List<String>> fetchCropTypes(final String cityId) =>
      _localDataSource.fetchCropTypes(cityId);

  @override
  Future<void> addCropType(final String cityId, final String cropType) =>
      _localDataSource.addCropType(cityId, cropType);

  @override
  Future<void> removeCropType(final String cityId, final String cropType) =>
      _localDataSource.removeCropType(cityId, cropType);
}
