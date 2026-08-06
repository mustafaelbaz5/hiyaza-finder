import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/services/sync_operation_handler.dart';
import 'parcel_sync_service.dart';

/// Executes a queued [AddParcelOperation] — the background half of
/// `HoldingsRepository.addLocalParcel`'s outbox path
/// (`REFACTOR_ROADMAP.md` Phase 9 #9). The local dataset is already
/// mutated optimistically by the time this runs; this only needs to make
/// the server call. Reconciling the client-generated id with a
/// server-assigned promotion (the old synchronous path's
/// `promotedHoldingId` swap) is deliberately **not** done here — that
/// correction now arrives the same way any other device's write would, via
/// the existing Realtime `holdings` INSERT/UPDATE path
/// (`HoldingsRepository.applyRemoteChange`), keeping this handler simple
/// and consistent with the multi-device model instead of duplicating
/// reconciliation logic in two places.
class AddParcelSyncHandler implements SyncOperationHandler {
  AddParcelSyncHandler(this._syncService);

  final ParcelSyncService _syncService;

  @override
  Future<void> execute(final SyncOperation operation) async {
    final AddParcelOperation op = operation as AddParcelOperation;
    await _syncService.syncAddParcel(
      parcelId: op.parcel.id,
      cityId: op.cityId,
      parcel: op.parcel,
      parentHoldingId: op.parentHoldingId,
    );
  }
}
