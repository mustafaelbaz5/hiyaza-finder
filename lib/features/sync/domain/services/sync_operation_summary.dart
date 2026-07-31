import 'package:easy_localization/easy_localization.dart';

import '../entities/sync_operation.dart';

/// A short, human-readable label for one [SyncOperation] — what the sync
/// details sheet shows next to each pending/failed item, so a user sees
/// *what* is queued instead of just a bare count.
String syncOperationSummary(final SyncOperation operation) {
  return switch (operation) {
    EditHoldingOperation() => 'sync.operation.edit_holding'.tr(),
    final BulkEditOperation o => 'sync.operation.bulk_edit'.tr(
        namedArgs: {'count': o.rows.length.toString()},
      ),
    final AddRecordOperation o => o.parentHoldingId == null
        ? 'sync.operation.add_person'.tr(
            namedArgs: {
              'name': (o.record['holder_name'] as String?)?.trim().isNotEmpty ==
                      true
                  ? o.record['holder_name'] as String
                  : 'sync.operation.unnamed'.tr(),
            },
          )
        : 'sync.operation.add_parcel'.tr(),
  };
}
