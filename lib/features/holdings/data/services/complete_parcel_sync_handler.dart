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
    // retried) for a parcel that's already in its desired state, for two
    // different reasons that both surface as a doomed retry loop if not
    // checked first:
    //  1. Someone else (another device, a prior attempt whose response was
    //     lost) already applied the same completed/not-completed value —
    //     `markCompleted`'s conflict check rejects a redundant write.
    //  2. `op.isFieldAdded` is stale — the parcel was promoted between
    //     `added_holdings` and `holdings` after this operation was queued,
    //     so `markCompleted`'s RPC (which trusts the caller's isFieldAdded
    //     to pick the table) looks in the wrong one and reports
    //     `found: false`, surfaced to the user as "couldn't find this
    //     record" even though the parcel is perfectly fine — just in the
    //     other table now.
    // Passing `isFieldAdded: null` (not `op.isFieldAdded`) checks BOTH
    // tables — deliberately not trusting the same cached flag that may be
    // the actual cause of the ambiguity being reconciled, mirroring
    // `HoldingsRepository.refreshParcel`'s identical reasoning. Whatever
    // table this finds the row in becomes the resolved `isFieldAdded` used
    // for the eventual write below, correcting the stale value instead of
    // repeating it.
    final result = await _api?.fetchParcelById(op.parcelId);
    final bool resolvedIsFieldAdded = result?.isFieldAdded ?? op.isFieldAdded;
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
      isFieldAdded: resolvedIsFieldAdded,
      completed: op.completed,
      completedAt: op.completedAt,
      completedByUserId: op.completedByUserId,
    );
  }
}
