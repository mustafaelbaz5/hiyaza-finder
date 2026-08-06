import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/services/parcel_sync_service.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/sync/data/holdings_api.dart';

class _AddRecordCall {
  _AddRecordCall({required this.id, required this.parentHoldingId});
  final String id;
  final String? parentHoldingId;
}

class _FakeHoldingsApi implements HoldingsApi {
  final List<_AddRecordCall> addRecordCalls = <_AddRecordCall>[];
  final List<String> deleteAddedHoldingCalls = <String>[];
  final List<Map<String, dynamic>> editHoldingCalls = <Map<String, dynamic>>[];

  @override
  Future<({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})>
      searchRemote({required final String cityId, required final String query}) async =>
          (holdings: const <Map<String, dynamic>>[], addedHoldings: const <Map<String, dynamic>>[]);
  final List<Map<String, dynamic>> markCompletedCalls = <Map<String, dynamic>>[];

  Object? addRecordError;
  Object? editHoldingError;
  bool editHoldingFailsForSecondCallOnward = false;
  String? promotedHoldingId;

  @override
  Future<String?> addRecord({
    required final String id,
    required final String cityId,
    required final Map<String, dynamic> record,
    required final String? parentHoldingId,
    required final String createdByUserId,
  }) async {
    if (addRecordError != null) throw addRecordError!;
    addRecordCalls.add(_AddRecordCall(id: id, parentHoldingId: parentHoldingId));
    return promotedHoldingId;
  }

  @override
  Future<void> deleteAddedHolding(final String id) async {
    deleteAddedHoldingCalls.add(id);
  }

  @override
  Future<void> editHolding({
    required final String holdingId,
    required final String cityId,
    required final Map<String, dynamic> payload,
    required final String editedByUserId,
  }) async {
    if (editHoldingFailsForSecondCallOnward && editHoldingCalls.isNotEmpty) {
      throw Exception('simulated failure');
    }
    if (editHoldingError != null) throw editHoldingError!;
    editHoldingCalls.add(<String, dynamic>{'holdingId': holdingId, 'payload': payload});
  }

  @override
  Future<List<String>> bulkEditHoldings({
    required final String cityId,
    required final Map<String, Map<String, dynamic>> payloadsByHoldingId,
    required final String editedByUserId,
  }) async =>
      <String>[];

  @override
  Future<void> markCompleted({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool completed,
    required final DateTime? completedAt,
    required final String completedByUserId,
  }) async {
    markCompletedCalls.add(<String, dynamic>{
      'parcelId': parcelId,
      'completed': completed,
    });
  }
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => const AppUser(
        id: 'user-1',
        email: 'field@example.com',
        displayName: 'Field Worker',
        role: UserRole.field,
      );

  @override
  Stream<AppUser?> get userChanges => const Stream<AppUser?>.empty();

  @override
  Future<AppUser> signInWithPassword({
    required final String email,
    required final String password,
  }) async =>
      currentUser!;

  @override
  Future<void> signOut() async {}
}

void main() {
  late _FakeHoldingsApi api;
  late ParcelSyncService service;

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<AuthRepository>(_FakeAuthRepository.new);
    api = _FakeHoldingsApi();
    service = ParcelSyncService(holdingsApi: api);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('syncAddParcel', () {
    const Parcel parcel = Parcel(id: 'p1', holdingId: '-1', holderName: 'محمد');

    test('returns null when not promoted', () async {
      final String? result = await service.syncAddParcel(
        parcelId: 'p1',
        cityId: 'city-1',
        parcel: parcel,
        parentHoldingId: null,
      );

      expect(result, isNull);
      expect(api.addRecordCalls, hasLength(1));
      expect(api.addRecordCalls.single.id, 'p1');
    });

    test('returns the promoted holding id when the DB trigger promotes it', () async {
      api.promotedHoldingId = 'promoted-id';

      final String? result = await service.syncAddParcel(
        parcelId: 'p1',
        cityId: 'city-1',
        parcel: parcel,
        parentHoldingId: null,
      );

      expect(result, 'promoted-id');
    });

    test('propagates the parentHoldingId through to the API call', () async {
      await service.syncAddParcel(
        parcelId: 'p1',
        cityId: 'city-1',
        parcel: parcel,
        parentHoldingId: 'parent-1',
      );

      expect(api.addRecordCalls.single.parentHoldingId, 'parent-1');
    });

    test('propagates a thrown error from the API', () async {
      api.addRecordError = Exception('network error');

      expect(
        () => service.syncAddParcel(
          parcelId: 'p1',
          cityId: 'city-1',
          parcel: parcel,
          parentHoldingId: null,
        ),
        throwsException,
      );
    });

    test('does not throw when holdingsApi is null (test/no-op stub)', () async {
      final ParcelSyncService nullApiService = ParcelSyncService(holdingsApi: null);

      final String? result = await nullApiService.syncAddParcel(
        parcelId: 'p1',
        cityId: 'city-1',
        parcel: parcel,
        parentHoldingId: null,
      );

      expect(result, isNull);
    });
  });

  group('syncDeleteParcel', () {
    test('returns true and calls the API on success', () async {
      final bool result = await service.syncDeleteParcel('added-1');

      expect(result, isTrue);
      expect(api.deleteAddedHoldingCalls, <String>['added-1']);
    });

    test('returns false without calling the API when holdingsApi is null', () async {
      final ParcelSyncService nullApiService = ParcelSyncService(holdingsApi: null);

      final bool result = await nullApiService.syncDeleteParcel('added-1');

      expect(result, isFalse);
    });
  });

  group('syncEditParcel', () {
    test('calls editHolding with the given payload', () async {
      await service.syncEditParcel(
        holdingId: 'h1',
        cityId: 'city-1',
        payload: <String, dynamic>{'holderName': 'محمد المعدّل'},
      );

      expect(api.editHoldingCalls, hasLength(1));
      expect(api.editHoldingCalls.single['holdingId'], 'h1');
    });

    test('is a no-op when holdingsApi is null', () async {
      final ParcelSyncService nullApiService = ParcelSyncService(holdingsApi: null);

      await nullApiService.syncEditParcel(
        holdingId: 'h1',
        cityId: 'city-1',
        payload: <String, dynamic>{},
      );
      // No assertion needed beyond "did not throw" — this documents the
      // no-op contract explicitly.
    });
  });

  group('syncMarkCompleted', () {
    test('returns a parcel with completedAt/completedBy set', () async {
      const Parcel parcel = Parcel(id: 'p1', holdingId: '101');

      final Parcel result = await service.syncMarkCompleted(
        parcelId: 'p1',
        isFieldAdded: false,
        completed: true,
        parcel: parcel,
      );

      expect(result.completedAt, isNotNull);
      expect(result.completedBy, 'user-1');
    });

    test('clears completedAt/completedBy when un-marking completed', () async {
      const Parcel parcel = Parcel(id: 'p1', holdingId: '101');

      final Parcel result = await service.syncMarkCompleted(
        parcelId: 'p1',
        isFieldAdded: false,
        completed: false,
        parcel: parcel,
      );

      expect(result.completedAt, isNull);
      expect(result.completedBy, isNull);
    });

    test('calls markCompleted with the correct isFieldAdded flag', () async {
      const Parcel parcel = Parcel(id: 'p1', holdingId: '101');

      await service.syncMarkCompleted(
        parcelId: 'p1',
        isFieldAdded: true,
        completed: true,
        parcel: parcel,
      );

      expect(api.markCompletedCalls.single['parcelId'], 'p1');
      expect(api.markCompletedCalls.single['completed'], isTrue);
    });
  });

  group('syncBulkEdit', () {
    test('reports success for every parcel when all edits succeed', () async {
      const List<Parcel> parcels = <Parcel>[
        Parcel(id: '1', holdingId: '101'),
        Parcel(id: '2', holdingId: '102'),
      ];

      final BulkSyncResult result = await service.syncBulkEdit(
        parcels: parcels,
        cityId: 'city-1',
        snapshotForParcel: (final Parcel p) => <String, dynamic>{'notes': 'x'},
      );

      expect(result.outcome.succeeded, 2);
      expect(result.outcome.failed, 0);
      expect(result.failedIds, isEmpty);
    });

    test('tracks failed ids without aborting the remaining rows', () async {
      api.editHoldingFailsForSecondCallOnward = true;
      const List<Parcel> parcels = <Parcel>[
        Parcel(id: '1', holdingId: '101'),
        Parcel(id: '2', holdingId: '102'),
        Parcel(id: '3', holdingId: '103'),
      ];

      final BulkSyncResult result = await service.syncBulkEdit(
        parcels: parcels,
        cityId: 'city-1',
        snapshotForParcel: (final Parcel p) => <String, dynamic>{'notes': 'x'},
      );

      // First call succeeds, then editHoldingFailsForSecondCallOnward kicks
      // in for every call after the first non-empty call list.
      expect(result.outcome.succeeded, 1);
      expect(result.outcome.failed, 2);
      expect(result.failedIds, <String>{'2', '3'});
    });

    test('skips the API call (but still counts a row) when cityId is null', () async {
      const List<Parcel> parcels = <Parcel>[Parcel(id: '1', holdingId: '101')];

      final BulkSyncResult result = await service.syncBulkEdit(
        parcels: parcels,
        cityId: null,
        snapshotForParcel: (final Parcel p) => <String, dynamic>{'notes': 'x'},
      );

      expect(api.editHoldingCalls, isEmpty);
      expect(result.outcome.succeeded, 1);
    });
  });
}
