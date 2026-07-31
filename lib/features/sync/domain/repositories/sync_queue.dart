import '../entities/sync_operation.dart';

/// The local outbox of pending writes. Enqueueing must never touch the
/// network — a use case writes the local snapshot/cache **and** enqueues
/// in the same call, then returns immediately (see `APP_PLAN.md` § 8).
abstract class SyncQueue {
  Future<void> enqueue(final SyncOperation operation);

  Future<List<SyncOperation>> pending();

  Future<void> remove(final String operationId);

  Future<void> update(final SyncOperation operation);

  Stream<int> get pendingCountChanges;
}
