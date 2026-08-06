import '../../../holdings/domain/entities/parcel.dart';
import 'sync_operation.dart';

/// (De)serializes [SyncOperation]s for durable on-device storage between app
/// launches — `SyncQueueStore` persists the queue as one JSON-encoded list
/// under a single `KeyValueStore` key (same pattern `ParcelEditsStore`
/// already uses for the edit overlay).
class SyncOperationCodec {
  const SyncOperationCodec();

  static const String _typeAdd = 'add';
  static const String _typeDelete = 'delete';
  static const String _typeEdit = 'edit';
  static const String _typeMarkReviewed = 'mark_reviewed';
  static const String _typeBulkEdit = 'bulk_edit';

  Map<String, dynamic> toJson(final SyncOperation op) {
    final Map<String, dynamic> base = <String, dynamic>{
      'operationId': op.operationId,
      'createdAt': op.createdAt.toIso8601String(),
      'attempts': op.attempts,
      'lastAttemptAt': op.lastAttemptAt?.toIso8601String(),
      'lastError': op.lastError,
    };

    return switch (op) {
      AddParcelOperation() => <String, dynamic>{
          ...base,
          'type': _typeAdd,
          'cityId': op.cityId,
          'parcel': op.parcel.toJson(),
          'parentHoldingId': op.parentHoldingId,
        },
      DeleteParcelOperation() => <String, dynamic>{
          ...base,
          'type': _typeDelete,
          'addedHoldingId': op.addedHoldingId,
        },
      EditParcelOperation() => <String, dynamic>{
          ...base,
          'type': _typeEdit,
          'holdingId': op.holdingId,
          'cityId': op.cityId,
          'payload': op.payload,
        },
      MarkReviewedOperation() => <String, dynamic>{
          ...base,
          'type': _typeMarkReviewed,
          'parcelId': op.parcelId,
          'isFieldAdded': op.isFieldAdded,
          'reviewed': op.reviewed,
          'reviewedAt': op.reviewedAt?.toIso8601String(),
          'reviewedByUserId': op.reviewedByUserId,
        },
      BulkEditOperation() => <String, dynamic>{
          ...base,
          'type': _typeBulkEdit,
          'holdingId': op.holdingId,
          'cityId': op.cityId,
          'payload': op.payload,
        },
    };
  }

  /// Returns `null` for a row this version of the codec doesn't recognize
  /// (e.g. a stale/corrupt entry) rather than throwing — one bad queued
  /// operation must never prevent the rest of the durable queue from
  /// loading on app start.
  SyncOperation? fromJson(final Map<String, dynamic> json) {
    try {
      final String operationId = json['operationId'] as String;
      final DateTime createdAt = DateTime.parse(json['createdAt'] as String);
      final int attempts = json['attempts'] as int? ?? 0;
      final DateTime? lastAttemptAt = json['lastAttemptAt'] == null
          ? null
          : DateTime.parse(json['lastAttemptAt'] as String);
      final String? lastError = json['lastError'] as String?;

      switch (json['type'] as String?) {
        case _typeAdd:
          return AddParcelOperation(
            operationId: operationId,
            createdAt: createdAt,
            attempts: attempts,
            lastAttemptAt: lastAttemptAt,
            lastError: lastError,
            cityId: json['cityId'] as String,
            parcel: Parcel.fromJson(json['parcel'] as Map<String, dynamic>),
            parentHoldingId: json['parentHoldingId'] as String?,
          );
        case _typeDelete:
          return DeleteParcelOperation(
            operationId: operationId,
            createdAt: createdAt,
            attempts: attempts,
            lastAttemptAt: lastAttemptAt,
            lastError: lastError,
            addedHoldingId: json['addedHoldingId'] as String,
          );
        case _typeEdit:
          return EditParcelOperation(
            operationId: operationId,
            createdAt: createdAt,
            attempts: attempts,
            lastAttemptAt: lastAttemptAt,
            lastError: lastError,
            holdingId: json['holdingId'] as String,
            cityId: json['cityId'] as String,
            payload: Map<String, dynamic>.from(
              json['payload'] as Map<dynamic, dynamic>,
            ),
          );
        case _typeMarkReviewed:
          return MarkReviewedOperation(
            operationId: operationId,
            createdAt: createdAt,
            attempts: attempts,
            lastAttemptAt: lastAttemptAt,
            lastError: lastError,
            parcelId: json['parcelId'] as String,
            isFieldAdded: json['isFieldAdded'] as bool,
            reviewed: json['reviewed'] as bool,
            reviewedAt: json['reviewedAt'] == null
                ? null
                : DateTime.parse(json['reviewedAt'] as String),
            reviewedByUserId: json['reviewedByUserId'] as String? ?? '',
          );
        case _typeBulkEdit:
          return BulkEditOperation(
            operationId: operationId,
            createdAt: createdAt,
            attempts: attempts,
            lastAttemptAt: lastAttemptAt,
            lastError: lastError,
            holdingId: json['holdingId'] as String,
            cityId: json['cityId'] as String,
            payload: Map<String, dynamic>.from(
              json['payload'] as Map<dynamic, dynamic>,
            ),
          );
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}
