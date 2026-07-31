/// A pending write queued while offline (or just to keep the UI from
/// waiting on the network) — see `APP_PLAN.md` § "Offline sync". Every
/// operation carries its own client-generated [id], which server-side
/// idempotency keys (`holding_edits.client_op_id`,
/// `added_holdings.client_id`) are keyed on, so a retry after a lost
/// response can never create a duplicate row.
sealed class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.createdAt,
    this.attempts = 0,
    this.lastAttemptAt,
    this.lastError,
  });

  final String id;
  final DateTime createdAt;
  final int attempts;

  /// When the last attempt was made — `null` until the first attempt.
  /// Drives the runner's exponential backoff: an operation is skipped
  /// until `lastAttemptAt + backoff(attempts)` has passed.
  final DateTime? lastAttemptAt;

  /// The exception message from the most recent failed attempt — `null`
  /// until the first failure. Surfaced on the sync details sheet so a
  /// failed operation isn't just a bare count with no explanation.
  final String? lastError;

  SyncOperation withIncrementedAttempts(
    final DateTime attemptedAt, {
    final String? error,
  });

  /// Clears [attempts]/[lastAttemptAt] so a permanently-failed operation
  /// (one at `syncMaxAttempts`) becomes eligible for the next flush again
  /// — the "retry" action on the sync status badge's failed state.
  SyncOperation resetAttempts();

  Map<String, dynamic> toJson();

  static SyncOperation fromJson(final Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'editHolding' => EditHoldingOperation.fromJson(json),
      'bulkEdit' => BulkEditOperation.fromJson(json),
      'addRecord' => AddRecordOperation.fromJson(json),
      final String other => throw ArgumentError('Unknown sync op type: $other'),
    };
  }
}

Map<String, dynamic> _baseJson(final SyncOperation o, final String type) => <String, dynamic>{
      'type': type,
      'id': o.id,
      'createdAt': o.createdAt.toIso8601String(),
      'attempts': o.attempts,
      'lastAttemptAt': o.lastAttemptAt?.toIso8601String(),
      'lastError': o.lastError,
    };

int _attemptsOf(final Map<String, dynamic> json) => json['attempts'] as int? ?? 0;

DateTime? _lastAttemptAtOf(final Map<String, dynamic> json) {
  final String? raw = json['lastAttemptAt'] as String?;
  return raw == null ? null : DateTime.parse(raw);
}

String? _lastErrorOf(final Map<String, dynamic> json) => json['lastError'] as String?;

/// A single-parcel field correction — mirrors `HoldingsRepository
/// .updateParcel()`. [payload] is the same `Parcel.toEditableJson()` shape
/// already used for the local edit overlay, so both sides read the exact
/// same field set.
final class EditHoldingOperation extends SyncOperation {
  const EditHoldingOperation({
    required super.id,
    required super.createdAt,
    super.attempts,
    super.lastAttemptAt,
    super.lastError,
    required this.cityId,
    required this.holdingId,
    required this.payload,
  });

  final String cityId;
  final String holdingId;
  final Map<String, dynamic> payload;

  @override
  EditHoldingOperation withIncrementedAttempts(
    final DateTime attemptedAt, {
    final String? error,
  }) =>
      EditHoldingOperation(
        id: id,
        createdAt: createdAt,
        attempts: attempts + 1,
        lastAttemptAt: attemptedAt,
        lastError: error,
        cityId: cityId,
        holdingId: holdingId,
        payload: payload,
      );

  @override
  EditHoldingOperation resetAttempts() => EditHoldingOperation(
        id: id,
        createdAt: createdAt,
        cityId: cityId,
        holdingId: holdingId,
        payload: payload,
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ..._baseJson(this, 'editHolding'),
        'cityId': cityId,
        'holdingId': holdingId,
        'payload': payload,
      };

  factory EditHoldingOperation.fromJson(final Map<String, dynamic> json) =>
      EditHoldingOperation(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        attempts: _attemptsOf(json),
        lastAttemptAt: _lastAttemptAtOf(json),
        lastError: _lastErrorOf(json),
        cityId: json['cityId'] as String,
        holdingId: json['holdingId'] as String,
        payload: json['payload'] as Map<String, dynamic>,
      );
}

/// One row of a [BulkEditOperation] — [payload] is that specific parcel's
/// **full** post-edit `toEditableJson()` snapshot, not just the changed
/// field. `holding_edits` rows are applied wholesale
/// (`ParcelEditOverlay.apply`/`Parcel.fromEditableJson` replace the whole
/// editable state, they don't merge field-by-field), and different
/// parcels in the same bulk edit can otherwise differ in every other
/// field — so a single shared partial payload would silently wipe out
/// each parcel's other previously-saved edits once applied on another
/// device. [opId] is this row's own stable `holding_edits.client_op_id`,
/// generated once when the operation is created and reused verbatim on
/// every retry, which is what makes each row's insert independently
/// idempotent.
class BulkEditRow {
  const BulkEditRow({
    required this.holdingId,
    required this.opId,
    required this.payload,
  });

  final String holdingId;
  final String opId;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'holdingId': holdingId,
        'opId': opId,
        'payload': payload,
      };

  factory BulkEditRow.fromJson(final Map<String, dynamic> json) => BulkEditRow(
        holdingId: json['holdingId'] as String,
        opId: json['opId'] as String,
        payload: json['payload'] as Map<String, dynamic>,
      );
}

/// The same field/value applied to many holdings at once — mirrors
/// `HoldingsRepository.bulkApplyField()`. Kept as one operation (rather
/// than one `EditHoldingOperation` per holding) so a basin-wide bulk edit
/// doesn't flood the outbox with hundreds of near-identical entries, while
/// each [rows] entry still carries its own full payload and idempotency id
/// (see [BulkEditRow]).
final class BulkEditOperation extends SyncOperation {
  const BulkEditOperation({
    required super.id,
    required super.createdAt,
    super.attempts,
    super.lastAttemptAt,
    super.lastError,
    required this.cityId,
    required this.rows,
  });

  final String cityId;
  final List<BulkEditRow> rows;

  @override
  BulkEditOperation withIncrementedAttempts(
    final DateTime attemptedAt, {
    final String? error,
  }) =>
      BulkEditOperation(
        id: id,
        createdAt: createdAt,
        attempts: attempts + 1,
        lastAttemptAt: attemptedAt,
        lastError: error,
        cityId: cityId,
        rows: rows,
      );

  @override
  BulkEditOperation resetAttempts() => BulkEditOperation(
        id: id,
        createdAt: createdAt,
        cityId: cityId,
        rows: rows,
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ..._baseJson(this, 'bulkEdit'),
        'cityId': cityId,
        'rows': rows.map((final BulkEditRow r) => r.toJson()).toList(),
      };

  factory BulkEditOperation.fromJson(final Map<String, dynamic> json) =>
      BulkEditOperation(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        attempts: _attemptsOf(json),
        lastAttemptAt: _lastAttemptAtOf(json),
        lastError: _lastErrorOf(json),
        cityId: json['cityId'] as String,
        rows: (json['rows'] as List<dynamic>)
            .map(
              (final dynamic e) => BulkEditRow.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}

/// A brand-new record created in the field — either a new person
/// ([parentHoldingId] `null`) or a new parcel for an existing person
/// ([parentHoldingId] set). [id] doubles as `added_holdings.client_id`.
/// [record] is the full `added_holdings` row shape (everything except
/// `city_id`/`client_id`/`parent_holding_id`/`created_by`, which the sync
/// runner fills in from the operation's own fields and the signed-in user).
final class AddRecordOperation extends SyncOperation {
  const AddRecordOperation({
    required super.id,
    required super.createdAt,
    super.attempts,
    super.lastAttemptAt,
    super.lastError,
    required this.cityId,
    required this.record,
    this.parentHoldingId,
  });

  final String cityId;
  final String? parentHoldingId;
  final Map<String, dynamic> record;

  @override
  AddRecordOperation withIncrementedAttempts(
    final DateTime attemptedAt, {
    final String? error,
  }) =>
      AddRecordOperation(
        id: id,
        createdAt: createdAt,
        attempts: attempts + 1,
        lastAttemptAt: attemptedAt,
        lastError: error,
        cityId: cityId,
        record: record,
        parentHoldingId: parentHoldingId,
      );

  @override
  AddRecordOperation resetAttempts() => AddRecordOperation(
        id: id,
        createdAt: createdAt,
        cityId: cityId,
        record: record,
        parentHoldingId: parentHoldingId,
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        ..._baseJson(this, 'addRecord'),
        'cityId': cityId,
        'parentHoldingId': parentHoldingId,
        'record': record,
      };

  factory AddRecordOperation.fromJson(final Map<String, dynamic> json) =>
      AddRecordOperation(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        attempts: _attemptsOf(json),
        lastAttemptAt: _lastAttemptAtOf(json),
        lastError: _lastErrorOf(json),
        cityId: json['cityId'] as String,
        parentHoldingId: json['parentHoldingId'] as String?,
        record: json['record'] as Map<String, dynamic>,
      );
}
