import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/repositories/sync_queue.dart';

class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> getString(final String key) async => _store[key];

  @override
  Future<void> remove(final String key) async => _store.remove(key);

  @override
  Future<void> setString(final String key, final String value) async {
    _store[key] = value;
  }
}

class _FakeSyncQueue implements SyncQueue {
  final List<SyncOperation> enqueued = <SyncOperation>[];

  @override
  Future<void> enqueue(final SyncOperation operation) async {
    enqueued.add(operation);
  }

  @override
  Future<List<SyncOperation>> pending() async => enqueued;

  @override
  Future<void> remove(final String operationId) async {
    enqueued.removeWhere((final SyncOperation o) => o.id == operationId);
  }

  @override
  Future<void> update(final SyncOperation operation) async {}

  @override
  Stream<int> get pendingCountChanges => const Stream<int>.empty();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._userId);

  final String? _userId;

  @override
  AppUser? get currentUser {
    final String? userId = _userId;
    if (userId == null) return null;
    return AppUser(
      id: userId,
      email: 'field@example.com',
      displayName: 'Field Worker',
      role: UserRole.field,
    );
  }

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
  late _FakeSyncQueue syncQueue;
  late HoldingsRepository repository;

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<AuthRepository>(() => _FakeAuthRepository('user-1'));

    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    syncQueue = _FakeSyncQueue();
    repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
      syncQueue: syncQueue,
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('returns null when the parcel is not in the active dataset', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
    final Parcel? result =
        await repository.setParcelReviewed('missing-id', reviewed: true);
    expect(result, isNull);
    expect(syncQueue.enqueued, isEmpty);
  });

  test('marks a holdings-origin (isFieldAdded: false) parcel reviewed locally and enqueues', () async {
    const Parcel parcel = Parcel(id: 'p-1', holdingId: '101');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    final Parcel? updated = await repository.setParcelReviewed('p-1', reviewed: true);

    expect(updated, isNotNull);
    expect(updated!.reviewed, isTrue);
    expect(updated.reviewedAt, isNotNull);
    expect(updated.reviewedBy, 'user-1');
    expect(repository.parcels.single.reviewed, isTrue);

    expect(syncQueue.enqueued, hasLength(1));
    final MarkParcelReviewedOperation op =
        syncQueue.enqueued.single as MarkParcelReviewedOperation;
    expect(op.cityId, 'city-1');
    expect(op.parcelId, 'p-1');
    expect(op.isFieldAdded, isFalse);
    expect(op.reviewed, isTrue);
    expect(op.reviewedAt, isNotNull);
  });

  test('marks an added_holdings-origin (isFieldAdded: true) parcel reviewed and enqueues with isFieldAdded true', () async {
    const Parcel parcel = Parcel(id: 'p-2', holdingId: '102', isFieldAdded: true);
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    await repository.setParcelReviewed('p-2', reviewed: true);

    final MarkParcelReviewedOperation op =
        syncQueue.enqueued.single as MarkParcelReviewedOperation;
    expect(op.isFieldAdded, isTrue);
  });

  test('finish then un-finish enqueues two ops in order, final local state is reviewed: false', () async {
    const Parcel parcel = Parcel(id: 'p-3', holdingId: '103');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    await repository.setParcelReviewed('p-3', reviewed: true);
    await repository.setParcelReviewed('p-3', reviewed: false);

    expect(syncQueue.enqueued, hasLength(2));
    expect((syncQueue.enqueued[0] as MarkParcelReviewedOperation).reviewed, isTrue);
    expect((syncQueue.enqueued[1] as MarkParcelReviewedOperation).reviewed, isFalse);

    final Parcel finalState = repository.parcels.single;
    expect(finalState.reviewed, isFalse);
    expect(finalState.reviewedAt, isNull);
    expect(finalState.reviewedBy, isNull);
  });

  group('applyRemoteChange race guard', () {
    test('a stale remote row (older reviewedAt) does not clobber a pending local write', () async {
      const Parcel parcel = Parcel(id: 'p-4', holdingId: '104');
      await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

      final Parcel? updated = await repository.setParcelReviewed('p-4', reviewed: true);
      final DateTime localReviewedAt = updated!.reviewedAt!;

      // A stale/racing remote row — reviewedAt earlier than the local write
      // (or null, e.g. an echo of the pre-write row).
      final Parcel staleRemote = parcel.copyWith(reviewed: false, reviewedAt: null);
      repository.applyRemoteChange(staleRemote);

      final Parcel afterStale = repository.parcels.single;
      expect(afterStale.reviewed, isTrue);
      expect(afterStale.reviewedAt, localReviewedAt);
    });

    test('a fresh remote row is adopted and clears the pending guard', () async {
      const Parcel parcel = Parcel(id: 'p-5', holdingId: '105');
      await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

      final Parcel? updated = await repository.setParcelReviewed('p-5', reviewed: true);
      final DateTime localReviewedAt = updated!.reviewedAt!;

      // A fresh remote row confirming the same (or later) reviewed state.
      final Parcel freshRemote = parcel.copyWith(
        reviewed: true,
        reviewedAt: localReviewedAt.add(const Duration(seconds: 1)),
        reviewedBy: 'user-1',
      );
      repository.applyRemoteChange(freshRemote);

      final Parcel afterFresh = repository.parcels.single;
      expect(afterFresh.reviewed, isTrue);
      expect(afterFresh.reviewedAt, freshRemote.reviewedAt);

      // Guard cleared — a subsequent stale-looking event no longer protected.
      final Parcel laterStale = parcel.copyWith(reviewed: false, reviewedAt: null);
      repository.applyRemoteChange(laterStale);
      expect(repository.parcels.single.reviewed, isFalse);
    });
  });
}
