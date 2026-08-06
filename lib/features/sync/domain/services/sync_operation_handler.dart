import '../entities/sync_operation.dart';

/// Executes one [SyncOperation] against the server — the "how" to
/// `SyncOperation`'s "what" (`SYSTEM_DESIGN.md` §5.1). `SyncRunner` (generic
/// infrastructure, zero feature imports) calls this without knowing what any
/// operation type actually does; the feature that owns the operation
/// (`holdings`) supplies the implementation via DI.
///
/// Throws on failure — `SyncRunner` catches, records the error on the
/// operation, and applies backoff before the next retry.
abstract class SyncOperationHandler {
  Future<void> execute(final SyncOperation operation);
}
