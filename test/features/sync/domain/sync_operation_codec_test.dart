import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation_codec.dart';

void main() {
  const SyncOperationCodec codec = SyncOperationCodec();
  final DateTime now = DateTime(2026, 8, 6, 12);

  group('SyncOperationCodec round-trip', () {
    test('AddParcelOperation', () {
      final AddParcelOperation original = AddParcelOperation(
        operationId: 'op1',
        createdAt: now,
        cityId: 'city1',
        parcel: const Parcel(id: 'p1', holdingId: '1', holderName: 'محمد'),
        parentHoldingId: 'parent1',
      );

      final SyncOperation? decoded = codec.fromJson(codec.toJson(original));

      expect(decoded, isA<AddParcelOperation>());
      final AddParcelOperation typed = decoded! as AddParcelOperation;
      expect(typed.operationId, 'op1');
      expect(typed.cityId, 'city1');
      expect(typed.parcel.id, 'p1');
      expect(typed.parcel.holderName, 'محمد');
      expect(typed.parentHoldingId, 'parent1');
    });

    test('DeleteParcelOperation', () {
      final DeleteParcelOperation original = DeleteParcelOperation(
        operationId: 'op2',
        createdAt: now,
        addedHoldingId: 'ah1',
      );

      final SyncOperation? decoded = codec.fromJson(codec.toJson(original));
      expect(decoded, isA<DeleteParcelOperation>());
      expect((decoded! as DeleteParcelOperation).addedHoldingId, 'ah1');
    });

    test('EditParcelOperation preserves payload map', () {
      final EditParcelOperation original = EditParcelOperation(
        operationId: 'op3',
        createdAt: now,
        holdingId: 'h1',
        cityId: 'city1',
        payload: const <String, dynamic>{'holder_name': 'أحمد', 'feddan': 2.5},
      );

      final SyncOperation? decoded = codec.fromJson(codec.toJson(original));
      expect(decoded, isA<EditParcelOperation>());
      final EditParcelOperation typed = decoded! as EditParcelOperation;
      expect(typed.payload['holder_name'], 'أحمد');
      expect(typed.payload['feddan'], 2.5);
    });

    test('MarkReviewedOperation', () {
      final MarkReviewedOperation original = MarkReviewedOperation(
        operationId: 'op4',
        createdAt: now,
        parcelId: 'p1',
        isFieldAdded: true,
        reviewed: true,
        reviewedAt: now,
        reviewedByUserId: 'user1',
      );

      final SyncOperation? decoded = codec.fromJson(codec.toJson(original));
      expect(decoded, isA<MarkReviewedOperation>());
      final MarkReviewedOperation typed = decoded! as MarkReviewedOperation;
      expect(typed.isFieldAdded, isTrue);
      expect(typed.reviewed, isTrue);
    });

    test('BulkEditOperation', () {
      final BulkEditOperation original = BulkEditOperation(
        operationId: 'op5',
        createdAt: now,
        holdingId: 'h1',
        cityId: 'city1',
        payload: const <String, dynamic>{'crop_type': 'قمح'},
      );

      final SyncOperation? decoded = codec.fromJson(codec.toJson(original));
      expect(decoded, isA<BulkEditOperation>());
    });

    test('preserves attempts/lastError across round-trip', () {
      final AddParcelOperation withFailure = AddParcelOperation(
        operationId: 'op6',
        createdAt: now,
        cityId: 'city1',
        parcel: const Parcel(holdingId: '1'),
        parentHoldingId: null,
      ).withAttempt(error: 'network timeout');

      final SyncOperation? decoded = codec.fromJson(codec.toJson(withFailure));
      expect(decoded!.attempts, 1);
      expect(decoded.lastError, 'network timeout');
      expect(decoded.lastAttemptAt, isNotNull);
    });

    test('returns null for an unrecognized type', () {
      final SyncOperation? decoded = codec.fromJson(<String, dynamic>{
        'operationId': 'x',
        'createdAt': now.toIso8601String(),
        'type': 'unknown_type',
      });
      expect(decoded, isNull);
    });

    test('returns null for malformed json rather than throwing', () {
      final SyncOperation? decoded = codec.fromJson(<String, dynamic>{
        'type': 'add',
        // Missing required fields.
      });
      expect(decoded, isNull);
    });
  });
}
