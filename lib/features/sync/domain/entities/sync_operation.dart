import '../../../holdings/domain/entities/parcel.dart';

/// A durable, serializable description of one pending write against
/// `holdings`/`added_holdings` — queued locally the moment the user takes
/// the action, executed (and retried) in the background by `SyncRunner`.
/// This class is pure data; it does not know how to execute itself (see
/// `SyncOperationHandler`, `SYSTEM_DESIGN.md` §5.1) — kept in `sync/domain`
/// rather than `holdings/domain` so `core/sync/` infrastructure never needs
/// to import a feature to know an operation's shape.
///
/// `REFACTOR_ROADMAP.md` Phase 9 #9 — the previously-abandoned outbox
/// design, rebuilt per explicit user sign-off. Idempotency reuses columns
/// already live on the server (`added_holdings.client_id`,
/// `holding_edits.client_op_id`) rather than inventing a new mechanism —
/// see `SYSTEM_DESIGN.md` §9.
sealed class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.createdAt,
    this.attempts = 0,
    this.lastAttemptAt,
    this.lastError,
  });

  /// Client-generated, stable across retries — doubles as the idempotency
  /// key sent to the server (`added_holdings.client_id` /
  /// `holding_edits.client_op_id`), so a retried operation that actually
  /// succeeded server-side on a prior attempt (but whose response was lost
  /// to a dropped connection) is never double-applied.
  final String operationId;

  final DateTime createdAt;

  /// How many times [SyncRunner] has attempted this operation. Capped at
  /// `SyncRunner.maxAttempts` before the operation is parked as
  /// permanently failed (visible, not auto-retried) rather than retried
  /// forever.
  final int attempts;

  final DateTime? lastAttemptAt;

  /// Human-readable reason the most recent attempt failed — shown in the
  /// pending/failed-syncs UI, `null` before the first failure.
  final String? lastError;

  SyncOperation withAttempt({required final String? error});
}

class AddParcelOperation extends SyncOperation {
  const AddParcelOperation({
    required super.operationId,
    required super.createdAt,
    required this.cityId,
    required this.parcel,
    required this.parentHoldingId,
    super.attempts = 0,
    super.lastAttemptAt,
    super.lastError,
  });

  final String cityId;
  final Parcel parcel;
  final String? parentHoldingId;

  @override
  AddParcelOperation withAttempt({required final String? error}) =>
      AddParcelOperation(
        operationId: operationId,
        createdAt: createdAt,
        cityId: cityId,
        parcel: parcel,
        parentHoldingId: parentHoldingId,
        attempts: attempts + 1,
        lastAttemptAt: DateTime.now(),
        lastError: error,
      );
}

class DeleteParcelOperation extends SyncOperation {
  const DeleteParcelOperation({
    required super.operationId,
    required super.createdAt,
    required this.addedHoldingId,
    super.attempts = 0,
    super.lastAttemptAt,
    super.lastError,
  });

  final String addedHoldingId;

  @override
  DeleteParcelOperation withAttempt({required final String? error}) =>
      DeleteParcelOperation(
        operationId: operationId,
        createdAt: createdAt,
        addedHoldingId: addedHoldingId,
        attempts: attempts + 1,
        lastAttemptAt: DateTime.now(),
        lastError: error,
      );
}

class EditParcelOperation extends SyncOperation {
  const EditParcelOperation({
    required super.operationId,
    required super.createdAt,
    required this.holdingId,
    required this.cityId,
    required this.payload,
    super.attempts = 0,
    super.lastAttemptAt,
    super.lastError,
  });

  final String holdingId;
  final String cityId;
  final Map<String, dynamic> payload;

  @override
  EditParcelOperation withAttempt({required final String? error}) =>
      EditParcelOperation(
        operationId: operationId,
        createdAt: createdAt,
        holdingId: holdingId,
        cityId: cityId,
        payload: payload,
        attempts: attempts + 1,
        lastAttemptAt: DateTime.now(),
        lastError: error,
      );
}

/// Field-worker completion (`completed_at`/`completed_by`) — never
/// `reviewed`/`reviewed_at`/`reviewed_by`, which is staff/Dashboard-only
/// (`SYSTEM_DESIGN.md` §10, `REFACTOR_ROADMAP.md` Phase 9 #12; this class
/// replaces the earlier `MarkReviewedOperation`, which conflated the two).
class CompleteParcelOperation extends SyncOperation {
  const CompleteParcelOperation({
    required super.operationId,
    required super.createdAt,
    required this.parcelId,
    required this.isFieldAdded,
    required this.completed,
    required this.completedAt,
    required this.completedByUserId,
    super.attempts = 0,
    super.lastAttemptAt,
    super.lastError,
  });

  final String parcelId;
  final bool isFieldAdded;
  final bool completed;

  /// Captured at enqueue time (not execute time) so the eventual server
  /// write matches exactly the value already applied to the local dataset
  /// optimistically — the two must never drift just because the operation
  /// sat in the queue for a while before actually running.
  final DateTime? completedAt;
  final String completedByUserId;

  @override
  CompleteParcelOperation withAttempt({required final String? error}) =>
      CompleteParcelOperation(
        operationId: operationId,
        createdAt: createdAt,
        parcelId: parcelId,
        isFieldAdded: isFieldAdded,
        completed: completed,
        completedAt: completedAt,
        completedByUserId: completedByUserId,
        attempts: attempts + 1,
        lastAttemptAt: DateTime.now(),
        lastError: error,
      );
}

/// One row of a bulk-edit batch — `HoldingsRepository.bulkApplyField`
/// enqueues one [BulkEditOperation] per affected parcel (not one operation
/// for the whole batch), so a single row's permanent failure never blocks
/// or loses the rest of the batch, matching the current synchronous
/// implementation's own per-row failure isolation.
class BulkEditOperation extends SyncOperation {
  const BulkEditOperation({
    required super.operationId,
    required super.createdAt,
    required this.holdingId,
    required this.cityId,
    required this.payload,
    super.attempts = 0,
    super.lastAttemptAt,
    super.lastError,
  });

  final String holdingId;
  final String cityId;
  final Map<String, dynamic> payload;

  @override
  BulkEditOperation withAttempt({required final String? error}) =>
      BulkEditOperation(
        operationId: operationId,
        createdAt: createdAt,
        holdingId: holdingId,
        cityId: cityId,
        payload: payload,
        attempts: attempts + 1,
        lastAttemptAt: DateTime.now(),
        lastError: error,
      );
}
