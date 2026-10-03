import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/model/jazla_transfer_bundle.dart';
import '../../data/repo/jazla_transfer_repository.dart';
import 'jazla_export_state.dart';
import 'package:share_plus/share_plus.dart';

import '../../../cities/data/model/association_type.dart';
import '../../../jazla/data/model/jazla.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_catalog/data/repo/parcel_catalog_repository.dart';
import '../../../parcel_export/data/local/export_file_saver.dart';

class JazlaExportCubit extends Cubit<JazlaExportState> {
  JazlaExportCubit(this._transferRepo, this._catalog)
      : super(const JazlaExportState.initial());

  final JazlaTransferRepository _transferRepo;
  final ParcelCatalogRepository _catalog;

  Future<void> exportAndShare({
    required final Jazla jazla,
    required final List<Parcel> parcels,
    final bool share = true,
  }) async {
    if (state.status == JazlaExportStatus.exporting) return;
    emit(state.copyWith(status: JazlaExportStatus.exporting));
    try {
      final String? cityId = _catalog.activeCityId;
      final String? cityName = _catalog.activeCityName;
      final String? associationName = _catalog.defaultAssociationName;
      final String? associationCode = _catalog.defaultAssociationCode;
      final AssociationType? associationType = _catalog.activeAssociationType;
      if (cityId == null ||
          cityName == null ||
          associationName == null ||
          associationType == null) {
        throw const FormatException('jazla.transfer.missing_context');
      }
      final JazlaTransferBundle bundle = await _transferRepo.buildExport(
        jazla: jazla,
        orderedParcels: parcels,
        cityId: cityId,
        cityName: cityName,
        associationName: associationName,
        associationCode: associationCode,
        associationType: associationType,
      );
      final bytes = await _transferRepo.encode(bundle);
      final String fileName = _fileName(cityName, jazla.name);
      final saveResult = await saveExportFile(
        bytes: bytes,
        fileName: fileName,
        allowedExtensions: const <String>['hiyaza-jazla'],
      );
      String? postSaveMessage;
      if (share) {
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: <XFile>[XFile(saveResult.filePath)],
              fileNameOverrides: <String>[fileName],
            ),
          );
        } catch (_) {
          postSaveMessage = 'jazla.transfer.share_failed';
        }
      }
      emit(state.copyWith(
        status: JazlaExportStatus.success,
        bundle: bundle,
        errorMessage: postSaveMessage,
      ));
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          status: JazlaExportStatus.error,
          errorMessage: error is FormatException
              ? error.message.toString()
              : 'jazla.transfer.error_export',
        ));
      }
    }
  }

  static String _fileName(final String cityName, final String jazlaName) {
    final String cleanCity = _clean(cityName);
    final String cleanJazla = _clean(jazlaName);
    final DateTime now = DateTime.now();
    return '${cleanCity}_${cleanJazla}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.hiyaza-jazla';
  }

  static String _clean(final String value) => value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .trim();
}
