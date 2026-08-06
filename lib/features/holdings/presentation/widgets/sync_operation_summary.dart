import 'package:easy_localization/easy_localization.dart';

import '../../../sync/domain/entities/sync_operation.dart';

/// One-line, localized description of what a queued [SyncOperation]
/// represents — used by the pending-syncs sheet so the user can tell what
/// each parked item actually is without reading raw field payloads.
String syncOperationSummary(final SyncOperation op) {
  return switch (op) {
    AddParcelOperation() => op.parentHoldingId == null
        ? 'sync.operation.add_person'
            .tr(namedArgs: {'name': op.parcel.holderName ?? 'sync.operation.unnamed'.tr()})
        : 'sync.operation.add_parcel'.tr(),
    DeleteParcelOperation() => 'sync.operation.delete_parcel'.tr(),
    EditParcelOperation() => 'sync.operation.edit_holding'.tr(),
    CompleteParcelOperation() => 'sync.operation.mark_reviewed'.tr(),
    BulkEditOperation() => 'sync.operation.bulk_edit'.tr(namedArgs: {'count': '1'}),
  };
}
