import '../../../sync/data/holdings_api.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/services/sync_operation_handler.dart';

class MarkReviewedSyncHandler implements SyncOperationHandler {
  MarkReviewedSyncHandler(this._api);

  final HoldingsApi? _api;

  @override
  Future<void> execute(final SyncOperation operation) async {
    final MarkReviewedOperation op = operation as MarkReviewedOperation;
    await _api?.markReviewed(
      parcelId: op.parcelId,
      isFieldAdded: op.isFieldAdded,
      reviewed: op.reviewed,
      reviewedAt: op.reviewedAt,
      reviewedByUserId: op.reviewedByUserId,
    );
  }
}
