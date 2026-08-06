import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/services/sync_operation_handler.dart';
import 'parcel_sync_service.dart';

class EditParcelSyncHandler implements SyncOperationHandler {
  EditParcelSyncHandler(this._syncService);

  final ParcelSyncService _syncService;

  @override
  Future<void> execute(final SyncOperation operation) async {
    final EditParcelOperation op = operation as EditParcelOperation;
    await _syncService.syncEditParcel(
      holdingId: op.holdingId,
      cityId: op.cityId,
      payload: op.payload,
    );
  }
}
