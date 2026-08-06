import 'package:get_it/get_it.dart';

import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../sync/data/holdings_api.dart';
import '../../domain/entities/bulk_edit_outcome.dart';
import '../../domain/entities/parcel.dart';
import '../added_holdings_mapper.dart';

/// Result of [ParcelSyncService.syncBulkEdit] — the aggregate outcome plus
/// which specific parcel ids failed, since [BulkEditOutcome] alone only
/// carries counts.
class BulkSyncResult {
  const BulkSyncResult({required this.outcome, required this.failedIds});

  final BulkEditOutcome outcome;
  final Set<String> failedIds;
}

/// Handles all network-facing parcel writes: adding, deleting, editing, and
/// marking reviewed. Encapsulates the Supabase API calls, taking input
/// parcels and returning confirmed results. Does not touch local state itself
/// — [HoldingsRepository] applies the confirmed result to [_parcels]/[_edits]
/// after this service succeeds.
class ParcelSyncService {
  ParcelSyncService({required this.holdingsApi});

  final HoldingsApi? holdingsApi;

  /// Inserts a new parcel into `added_holdings`, awaiting server confirmation.
  /// Returns the promoted holding's id if auto-approved by a trigger, or
  /// `null` if [holdingsApi] is `null` (tests, or a no-op network stub).
  ///
  /// Throws on failure; caller catches and propagates to user.
  Future<String?> syncAddParcel({
    required final String parcelId,
    required final String cityId,
    required final Parcel parcel,
    required final String? parentHoldingId,
  }) async {
    final String currentUserId =
        GetIt.instance<AuthRepository>().currentUser?.id ?? '';
    return holdingsApi?.addRecord(
      id: parcelId,
      cityId: cityId,
      record: parcelToAddedHoldingsRecord(parcel),
      parentHoldingId: parentHoldingId,
      createdByUserId: currentUserId,
    );
  }

  /// Deletes a field-created parcel from `added_holdings`, awaiting server
  /// confirmation. Returns `true` on success, `false` if [holdingsApi] is null.
  ///
  /// Throws on failure; caller catches and propagates to user.
  Future<bool> syncDeleteParcel(final String addedHoldingId) async {
    if (holdingsApi == null) return false;
    await holdingsApi!.deleteAddedHolding(addedHoldingId);
    return true;
  }

  /// Persists an edited parcel to `holding_edits`, awaiting server confirmation.
  /// Does nothing (no-op) if [holdingsApi] is null.
  ///
  /// Throws on failure; caller catches and propagates to user.
  Future<void> syncEditParcel({
    required final String holdingId,
    required final String cityId,
    required final Map<String, dynamic> payload,
  }) async {
    final String currentUserId =
        GetIt.instance<AuthRepository>().currentUser?.id ?? '';
    if (holdingsApi != null) {
      await holdingsApi!.editHolding(
        holdingId: holdingId,
        cityId: cityId,
        payload: payload,
        editedByUserId: currentUserId,
      );
    }
  }

  /// Marks a parcel completed/reopened on its `holdings`/`added_holdings`
  /// row, awaiting server confirmation. Returns the updated parcel on
  /// success. Writes `completed_at`/`completed_by` — the field-worker
  /// completion signal — never `reviewed`/`reviewed_at`/`reviewed_by`
  /// (staff/Dashboard-only, `SYSTEM_DESIGN.md` §10).
  ///
  /// Throws on failure; caller catches and propagates to user.
  Future<Parcel> syncMarkCompleted({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool completed,
    required final Parcel parcel,
  }) async {
    final DateTime? completedAt = completed ? DateTime.now() : null;
    final String? currentUserId =
        GetIt.instance<AuthRepository>().currentUser?.id;

    if (holdingsApi != null) {
      await holdingsApi!.markCompleted(
        parcelId: parcelId,
        isFieldAdded: isFieldAdded,
        completed: completed,
        completedAt: completedAt,
        completedByUserId: currentUserId ?? '',
      );
    }

    return parcel.copyWith(
      completedAt: completedAt,
      completedBy: completed ? currentUserId : null,
    );
  }

  /// Applies a bulk edit to multiple parcels' rows in `holding_edits`,
  /// continuing past per-row failures. Returns the outcome plus the set of
  /// parcel ids that failed, so the caller can keep those rows' pre-edit
  /// value both on screen and in its own edit overlay.
  ///
  /// Does not throw; exceptions are caught and counted as failures.
  Future<BulkSyncResult> syncBulkEdit({
    required final List<Parcel> parcels,
    required final String? cityId,
    required final Map<String, dynamic> Function(Parcel p) snapshotForParcel,
  }) async {
    final String currentUserId =
        GetIt.instance<AuthRepository>().currentUser?.id ?? '';

    int succeeded = 0;
    final Set<String> failedIds = <String>{};

    for (final Parcel p in parcels) {
      final Map<String, dynamic> snapshot = snapshotForParcel(p);
      try {
        if (cityId != null) {
          await holdingsApi?.editHolding(
            holdingId: p.id,
            cityId: cityId,
            payload: snapshot,
            editedByUserId: currentUserId,
          );
        }
        succeeded++;
      } catch (_) {
        failedIds.add(p.id);
      }
    }

    return BulkSyncResult(
      outcome: BulkEditOutcome(succeeded: succeeded, failed: failedIds.length),
      failedIds: failedIds,
    );
  }
}
