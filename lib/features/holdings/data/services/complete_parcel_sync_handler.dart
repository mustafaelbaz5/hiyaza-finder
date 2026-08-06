import '../../../sync/data/holdings_api.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/services/sync_operation_handler.dart';

class CompleteParcelSyncHandler implements SyncOperationHandler {
  CompleteParcelSyncHandler(this._api);

  final HoldingsApi? _api;

  @override
  Future<void> execute(final SyncOperation operation) async {
    final CompleteParcelOperation op = operation as CompleteParcelOperation;
    await _api?.markCompleted(
      parcelId: op.parcelId,
      isFieldAdded: op.isFieldAdded,
      completed: op.completed,
      completedAt: op.completedAt,
      completedByUserId: op.completedByUserId,
    );
  }
}
