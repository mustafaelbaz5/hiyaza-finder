import '../entities/sync_operation.dart';

/// The network boundary for pushing queued operations — kept separate
/// from [SyncQueue] (interface segregation) and from the concrete
/// Supabase implementation, so [SyncRunner]-equivalents can be tested
/// against a fake instead of a live network.
///
/// Every push method must be idempotent: calling it twice with the same
/// operation succeeds both times (the second as a harmless no-op) rather
/// than creating a duplicate row or throwing.
abstract class SyncApi {
  Future<void> pushEditHolding(
    final EditHoldingOperation operation, {
    required final String editedByUserId,
  });

  Future<void> pushBulkEdit(
    final BulkEditOperation operation, {
    required final String editedByUserId,
  });

  Future<void> pushAddRecord(
    final AddRecordOperation operation, {
    required final String createdByUserId,
  });
}
