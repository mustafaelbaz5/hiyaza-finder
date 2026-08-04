import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';

void main() {
  group('EditHoldingOperation', () {
    test('toJson -> fromJson round-trips', () {
      final EditHoldingOperation op = EditHoldingOperation(
        id: 'op-1',
        createdAt: DateTime(2026, 1, 1, 10),
        attempts: 2,
        lastAttemptAt: DateTime(2026, 1, 1, 10, 5),
        cityId: 'city-1',
        holdingId: 'holding-1',
        payload: const <String, dynamic>{'notes': 'test'},
      );

      final SyncOperation restored = SyncOperation.fromJson(op.toJson());

      expect(restored, isA<EditHoldingOperation>());
      final EditHoldingOperation r = restored as EditHoldingOperation;
      expect(r.id, 'op-1');
      expect(r.attempts, 2);
      expect(r.cityId, 'city-1');
      expect(r.holdingId, 'holding-1');
      expect(r.payload, <String, dynamic>{'notes': 'test'});
      expect(r.lastAttemptAt, DateTime(2026, 1, 1, 10, 5));
    });

    test('withIncrementedAttempts bumps attempts and sets lastAttemptAt', () {
      final EditHoldingOperation op = EditHoldingOperation(
        id: 'op-1',
        createdAt: DateTime(2026),
        cityId: 'c',
        holdingId: 'h',
        payload: const <String, dynamic>{},
      );
      final DateTime attemptedAt = DateTime(2026, 2, 1);
      final EditHoldingOperation bumped = op.withIncrementedAttempts(attemptedAt);

      expect(bumped.attempts, 1);
      expect(bumped.lastAttemptAt, attemptedAt);
      expect(bumped.id, op.id);
    });
  });

  group('BulkEditOperation', () {
    test('toJson -> fromJson round-trips multiple rows', () {
      final BulkEditOperation op = BulkEditOperation(
        id: 'bulk-1',
        createdAt: DateTime(2026, 1, 1),
        cityId: 'city-1',
        rows: const <BulkEditRow>[
          BulkEditRow(
            holdingId: 'h1',
            opId: 'row-op-1',
            payload: <String, dynamic>{'cropType': 'قمح'},
          ),
          BulkEditRow(
            holdingId: 'h2',
            opId: 'row-op-2',
            payload: <String, dynamic>{'cropType': 'قمح'},
          ),
        ],
      );

      final SyncOperation restored = SyncOperation.fromJson(op.toJson());
      final BulkEditOperation r = restored as BulkEditOperation;

      expect(r.rows, hasLength(2));
      expect(r.rows[0].holdingId, 'h1');
      expect(r.rows[0].opId, 'row-op-1');
      expect(r.rows[1].holdingId, 'h2');
    });
  });

  group('AddRecordOperation', () {
    test('toJson -> fromJson round-trips, including a null parentHoldingId', () {
      final AddRecordOperation op = AddRecordOperation(
        id: 'add-1',
        createdAt: DateTime(2026, 1, 1),
        cityId: 'city-1',
        record: const <String, dynamic>{'holder_name': 'محمد'},
      );

      final SyncOperation restored = SyncOperation.fromJson(op.toJson());
      final AddRecordOperation r = restored as AddRecordOperation;

      expect(r.parentHoldingId, isNull);
      expect(r.record['holder_name'], 'محمد');
    });

    test('parentHoldingId survives the round-trip when set', () {
      final AddRecordOperation op = AddRecordOperation(
        id: 'add-2',
        createdAt: DateTime(2026, 1, 1),
        cityId: 'city-1',
        parentHoldingId: 'parent-1',
        record: const <String, dynamic>{'holder_name': 'محمد'},
      );

      final AddRecordOperation r = SyncOperation.fromJson(op.toJson()) as AddRecordOperation;
      expect(r.parentHoldingId, 'parent-1');
    });
  });

  test('resetAttempts clears attempts and lastAttemptAt, keeps the payload', () {
    final EditHoldingOperation op = EditHoldingOperation(
      id: 'op-1',
      createdAt: DateTime(2026),
      attempts: 5,
      lastAttemptAt: DateTime(2026, 1, 2),
      cityId: 'c',
      holdingId: 'h',
      payload: const <String, dynamic>{'notes': 'x'},
    );

    final EditHoldingOperation reset = op.resetAttempts();

    expect(reset.attempts, 0);
    expect(reset.lastAttemptAt, isNull);
    expect(reset.id, 'op-1');
    expect(reset.payload, <String, dynamic>{'notes': 'x'});
  });

  test('withIncrementedAttempts records the error message', () {
    final EditHoldingOperation op = EditHoldingOperation(
      id: 'op-1',
      createdAt: DateTime(2026),
      cityId: 'c',
      holdingId: 'h',
      payload: const <String, dynamic>{},
    );

    final EditHoldingOperation bumped = op.withIncrementedAttempts(
      DateTime(2026, 2, 1),
      error: 'network error',
    );

    expect(bumped.lastError, 'network error');
  });

  test('resetAttempts clears lastError', () {
    final EditHoldingOperation op = EditHoldingOperation(
      id: 'op-1',
      createdAt: DateTime(2026),
      attempts: 5,
      lastAttemptAt: DateTime(2026, 1, 2),
      lastError: 'network error',
      cityId: 'c',
      holdingId: 'h',
      payload: const <String, dynamic>{},
    );

    expect(op.resetAttempts().lastError, isNull);
  });

  test('lastError round-trips through toJson/fromJson', () {
    final EditHoldingOperation op = EditHoldingOperation(
      id: 'op-1',
      createdAt: DateTime(2026),
      attempts: 1,
      lastAttemptAt: DateTime(2026, 1, 2),
      lastError: 'server rejected the record',
      cityId: 'c',
      holdingId: 'h',
      payload: const <String, dynamic>{},
    );

    final SyncOperation restored = SyncOperation.fromJson(op.toJson());

    expect(restored.lastError, 'server rejected the record');
  });

  test('fromJson throws on an unknown type', () {
    expect(
      () => SyncOperation.fromJson(<String, dynamic>{'type': 'nope'}),
      throwsArgumentError,
    );
  });

  group('MarkParcelReviewedOperation', () {
    test('toJson -> fromJson round-trips when marking reviewed', () {
      final MarkParcelReviewedOperation op = MarkParcelReviewedOperation(
        id: 'rev-1',
        createdAt: DateTime(2026, 1, 1, 10),
        cityId: 'city-1',
        parcelId: 'parcel-1',
        isFieldAdded: false,
        reviewed: true,
        reviewedAt: DateTime(2026, 1, 1, 10, 5),
      );

      final SyncOperation restored = SyncOperation.fromJson(op.toJson());

      expect(restored, isA<MarkParcelReviewedOperation>());
      final MarkParcelReviewedOperation r = restored as MarkParcelReviewedOperation;
      expect(r.id, 'rev-1');
      expect(r.cityId, 'city-1');
      expect(r.parcelId, 'parcel-1');
      expect(r.isFieldAdded, isFalse);
      expect(r.reviewed, isTrue);
      expect(r.reviewedAt, DateTime(2026, 1, 1, 10, 5));
    });

    test('toJson -> fromJson round-trips a null reviewedAt (un-review)', () {
      final MarkParcelReviewedOperation op = MarkParcelReviewedOperation(
        id: 'rev-2',
        createdAt: DateTime(2026, 1, 1),
        cityId: 'city-1',
        parcelId: 'parcel-1',
        isFieldAdded: true,
        reviewed: false,
        reviewedAt: null,
      );

      final MarkParcelReviewedOperation r =
          SyncOperation.fromJson(op.toJson()) as MarkParcelReviewedOperation;

      expect(r.reviewed, isFalse);
      expect(r.reviewedAt, isNull);
      expect(r.isFieldAdded, isTrue);
    });

    test('withIncrementedAttempts/resetAttempts preserve all fields', () {
      final MarkParcelReviewedOperation op = MarkParcelReviewedOperation(
        id: 'rev-3',
        createdAt: DateTime(2026),
        cityId: 'city-1',
        parcelId: 'parcel-1',
        isFieldAdded: false,
        reviewed: true,
        reviewedAt: DateTime(2026),
      );

      final MarkParcelReviewedOperation bumped = op.withIncrementedAttempts(
        DateTime(2026, 2, 1),
        error: 'network error',
      );
      expect(bumped.attempts, 1);
      expect(bumped.lastError, 'network error');
      expect(bumped.parcelId, 'parcel-1');

      final MarkParcelReviewedOperation reset = bumped.resetAttempts();
      expect(reset.attempts, 0);
      expect(reset.lastAttemptAt, isNull);
      expect(reset.parcelId, 'parcel-1');
      expect(reset.reviewed, isTrue);
    });
  });
}
