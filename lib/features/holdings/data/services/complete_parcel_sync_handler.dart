import 'package:flutter/foundation.dart' show debugPrint;

import '../../../sync/data/holdings_api.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/services/sync_operation_handler.dart';

class CompleteParcelSyncHandler implements SyncOperationHandler {
  CompleteParcelSyncHandler(this._api);

  final HoldingsApi? _api;

  @override
  Future<void> execute(final SyncOperation operation) async {
    final CompleteParcelOperation op = operation as CompleteParcelOperation;

    // Reconciles before writing — this operation can end up queued (and
    // retried) for a parcel someone else (another device, a prior attempt
    // whose response was lost) already marked reviewed. Retrying blindly
    // guarantees `markCompleted`'s server-side conflict check rejects it
    // every single time, which looks to the user like a permanently broken
    // sync (`لا يوجد اتصال بالإنترنت` was previously shown for this exact
    // case, misleadingly framing a real conflict as a connectivity
    // problem). Checking first means: if the server already reflects what
    // this operation wants, treat it as already-done and let it succeed
    // (removing itself from the queue) instead of throwing — the eventual
    // consistency this outbox exists for was already achieved by another
    // path.
    final result = await _api?.fetchParcelById(
      op.parcelId,
      isFieldAdded: op.isFieldAdded,
    );
    if (result != null) {
      final bool alreadyCompleted = result.row['completed_at'] != null;
      if (op.completed == alreadyCompleted) {
        debugPrint(
          '[CompleteParcelSyncHandler] parcelId=${op.parcelId} already '
          'reflects the desired completed=${op.completed} state on the '
          'server — skipping the write, treating this attempt as a success.',
        );
        return;
      }
    }

    await _api?.markCompleted(
      parcelId: op.parcelId,
      isFieldAdded: op.isFieldAdded,
      completed: op.completed,
      completedAt: op.completedAt,
      completedByUserId: op.completedByUserId,
    );
  }
}
