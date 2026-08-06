import 'package:get_it/get_it.dart';

import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../sync/data/holdings_api.dart';
import '../../../sync/domain/entities/sync_operation.dart';
import '../../../sync/domain/services/sync_operation_handler.dart';

class BulkEditSyncHandler implements SyncOperationHandler {
  BulkEditSyncHandler(this._api);

  final HoldingsApi? _api;

  @override
  Future<void> execute(final SyncOperation operation) async {
    final BulkEditOperation op = operation as BulkEditOperation;
    final String currentUserId =
        GetIt.instance<AuthRepository>().currentUser?.id ?? '';
    await _api?.editHolding(
      holdingId: op.holdingId,
      cityId: op.cityId,
      payload: op.payload,
      editedByUserId: currentUserId,
    );
  }
}
