import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
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

void main() {
  late _FakeSyncQueue syncQueue;
  late HoldingsRepository repository;

  setUp(() async {
    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    syncQueue = _FakeSyncQueue();
    repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
      syncQueue: syncQueue,
    );
    // Simulate an active city (addLocalParcel is a no-op without one).
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  });

  test('returns null and enqueues nothing when no city is active', () async {
    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    final HoldingsRepository noCityRepo = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
      syncQueue: syncQueue,
    );
    final Parcel? result = await noCityRepo.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );
    expect(result, isNull);
    expect(syncQueue.enqueued, isEmpty);
  });

  test('appends the new parcel to the in-memory dataset with a fresh id', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(added, isNotNull);
    expect(added!.id, isNotEmpty);
    expect(repository.parcels, hasLength(1));
    expect(repository.parcels.single.holderName, 'محمد');
  });

  test('enqueues an AddRecordOperation with a null parentHoldingId for a new person', () async {
    await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(syncQueue.enqueued, hasLength(1));
    final AddRecordOperation op = syncQueue.enqueued.single as AddRecordOperation;
    expect(op.cityId, 'city-1');
    expect(op.parentHoldingId, isNull);
    expect(op.record['holder_name'], 'محمد');
  });

  test('enqueues an AddRecordOperation with the given parentHoldingId for a new parcel', () async {
    await repository.addLocalParcel(
      const Parcel(holdingId: '101', holderName: 'محمد', landNumber: '-1'),
      parentHoldingId: 'existing-holding-id',
    );

    final AddRecordOperation op = syncQueue.enqueued.single as AddRecordOperation;
    expect(op.parentHoldingId, 'existing-holding-id');
  });

  test(
      'sends the real holdings.id as parentHoldingId when the parent parcel '
      'is an imported (not field-added) holding', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[
      Parcel(id: 'imported-holding-id', holdingId: '229', holderName: 'محمد', isFieldAdded: false),
    ]);

    await repository.addLocalParcel(
      const Parcel(holdingId: '229', holderName: 'محمد', landNumber: '-1'),
      parentHoldingId: 'imported-holding-id',
    );

    final AddRecordOperation op = syncQueue.enqueued.single as AddRecordOperation;
    expect(op.parentHoldingId, 'imported-holding-id');
  });

  test(
      'nulls out parentHoldingId when the parent parcel is field-added '
      '(added_holdings-origin), even across a fresh session where '
      "_locallyAddedIds wouldn't know about it — regression test for the "
      'added_holdings_parent_holding_id_fkey violation: an added_holdings.id '
      'is never a valid holdings.id, so it must never be sent as '
      'parent_holding_id regardless of when/how the parent parcel was '
      'loaded', () async {
    // Simulates a person whose record is a previously-synced, unpromoted
    // added_holdings row, downloaded fresh this session (so it was never
    // added via addLocalParcel and is NOT in _locallyAddedIds) — exactly
    // the scenario from the FK-violation bug report.
    await repository.loadParcelsForCity('city-1', const <Parcel>[
      Parcel(id: 'added-holdings-row-id', holdingId: '229', holderName: 'محمد', isFieldAdded: true),
    ]);

    await repository.addLocalParcel(
      const Parcel(holdingId: '229', holderName: 'محمد', landNumber: '-1'),
      parentHoldingId: 'added-holdings-row-id',
    );

    final AddRecordOperation op = syncQueue.enqueued.single as AddRecordOperation;
    expect(op.parentHoldingId, isNull);
  });

  test('the operation id matches the new parcel\'s id (doubles as client_id)', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );
    final AddRecordOperation op = syncQueue.enqueued.single as AddRecordOperation;
    expect(op.id, added!.id);
  });

  test('isNewLocalRecord is true for a just-added parcel and false otherwise', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(repository.isNewLocalRecord(added!.id), isTrue);
    expect(repository.isNewLocalRecord('some-other-id'), isFalse);
  });
}
