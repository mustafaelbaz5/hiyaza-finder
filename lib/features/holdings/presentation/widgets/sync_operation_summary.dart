import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/parcel.dart';
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

/// The parcel this operation targets, if it's still in the currently-loaded
/// dataset — used only to enrich the pending-syncs sheet's detail line
/// (holder name, رقم الحيازة) for operation types that carry only an id, not
/// a full [Parcel] snapshot. `null` is expected and harmless (a different
/// city loaded, or the parcel not found locally) — the detail line falls
/// back to showing just the id in that case.
Parcel? syncOperationTargetParcel(
  final SyncOperation op,
  final List<Parcel> parcels,
) {
  final String? targetId = switch (op) {
    AddParcelOperation() => null, // already carries the full Parcel itself
    DeleteParcelOperation(:final addedHoldingId) => addedHoldingId,
    EditParcelOperation(:final holdingId) => holdingId,
    CompleteParcelOperation(:final parcelId) => parcelId,
    BulkEditOperation(:final holdingId) => holdingId,
  };
  if (targetId == null) return null;
  for (final Parcel p in parcels) {
    if (p.id == targetId) return p;
  }
  return null;
}

/// One-line detail shown under the summary — who/which holding this
/// operation targets, when it was first queued, and how many attempts have
/// been made so far. Kept separate from [syncOperationSummary] (a short
/// action label) and the operation's own [SyncOperation.lastError] (the
/// failure reason, shown separately) so the sheet can lay out "what /
/// who / when / how many tries" independently of "why it failed".
String syncOperationDetailLine(final SyncOperation op, final List<Parcel> parcels) {
  final Parcel? target = syncOperationTargetParcel(op, parcels);
  final String who = switch (op) {
    AddParcelOperation(:final parcel) => parcel.holderName ?? 'sync.operation.unnamed'.tr(),
    _ => target?.holderName ?? 'sync.operation.unnamed'.tr(),
  };
  final String? holdingId = switch (op) {
    AddParcelOperation(:final parcel) => parcel.holdingId,
    _ => target?.holdingId,
  };

  final String queuedAt = 'sync.details.queued_at'.tr(
    namedArgs: {'time': _formatTimestamp(op.createdAt)},
  );
  final String attempts = op.attempts > 0
      ? 'sync.details.attempts'.tr(namedArgs: {'count': op.attempts.toString()})
      : '';

  final String person = holdingId != null && holdingId.trim().isNotEmpty
      ? '$who — #$holdingId'
      : who;

  return <String>[person, queuedAt, attempts]
      .where((final String s) => s.isNotEmpty)
      .join(' • ');
}

String _formatTimestamp(final DateTime time) {
  final DateTime local = time.toLocal();
  String two(final int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
