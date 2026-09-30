import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../jazla/data/repo/jazla_repo.dart';
import '../../../parcel_catalog/data/repo/parcel_catalog_repository.dart';
import '../../data/local/jazla_transfer_matcher.dart';
import '../../data/model/jazla_transfer_bundle.dart';
import '../../data/repo/jazla_transfer_repository.dart';
import 'jazla_import_state.dart';

class JazlaImportCubit extends Cubit<JazlaImportState> {
  JazlaImportCubit(
    this._transferRepo,
    this._catalog,
    this._jazlaRepo,
  ) : super(const JazlaImportState.initial());

  final JazlaTransferRepository _transferRepo;
  final ParcelCatalogRepository _catalog;
  final JazlaRepo _jazlaRepo;
  static const JazlaTransferMatcher _matcher = JazlaTransferMatcher();

  Future<void> pickAndValidate() async {
    if (state.status == JazlaImportStatus.reading ||
        state.status == JazlaImportStatus.importing) {
      return;
    }
    emit(state.copyWith(status: JazlaImportStatus.reading));
    try {
      final JazlaTransferBundle bundle = await _transferRepo.readFile();
      final String? mismatch = _matcher.mismatch(
        manifest: bundle.manifest,
        cityId: _catalog.activeCityId ?? '',
        cityName: _catalog.activeCityName ?? '',
        associationName: _catalog.defaultAssociationName,
        associationCode: _catalog.defaultAssociationCode,
        associationType: _catalog.activeAssociationType,
      );
      if (mismatch != null) {
        throw FormatException(mismatch);
      }
      final bool conflict = (await _jazlaRepo.getAll(bundle.jazla.cityId))
          .any((final jazla) => jazla.id == bundle.jazla.id);
      emit(state.copyWith(
        status: JazlaImportStatus.preview,
        bundle: bundle,
        hasConflict: conflict,
      ));
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          status: JazlaImportStatus.error,
          errorMessage: error is FormatException
              ? error.message.toString()
              : 'jazla.transfer.error_read',
        ));
      }
    }
  }

  Future<bool> confirmImport({required final bool replace}) async {
    final JazlaTransferBundle? bundle = state.bundle;
    if (bundle == null || state.status != JazlaImportStatus.preview) {
      return false;
    }
    emit(state.copyWith(status: JazlaImportStatus.importing));
    try {
      await _transferRepo.importBundle(bundle, replace: replace);
      emit(state.copyWith(status: JazlaImportStatus.success));
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          status: JazlaImportStatus.error,
          errorMessage: error is FormatException
              ? error.message.toString()
              : 'jazla.transfer.error_import',
        ));
      }
      return false;
    }
  }
}
