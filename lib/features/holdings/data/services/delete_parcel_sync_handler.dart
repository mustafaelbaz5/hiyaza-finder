import '../../../sync/data/holdings_api.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/services/sync_operation_handler.dart';

class DeleteParcelSyncHandler implements SyncOperationHandler {
  DeleteParcelSyncHandler(this._api);

  final HoldingsApi? _api;

  @override
  Future<void> execute(final SyncOperation operation) async {
    final DeleteParcelOperation op = operation as DeleteParcelOperation;
    await _api?.deleteAddedHolding(op.addedHoldingId);
  }
}
