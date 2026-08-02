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
    syncQueue = _FakeSyncQueue();
    repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
      syncQueue: syncQueue,
    );
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  });

  test('an unsynced field-added parcel can be deleted', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(await repository.canDeleteLocalParcel(added!.id), isTrue);
    expect(await repository.deleteLocalParcel(added.id), isTrue);
    expect(repository.parcels, isEmpty);
    expect(syncQueue.enqueued, isEmpty); // AddRecordOperation removed too
  });

  test('a parcel already synced (no pending op) cannot be deleted', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );
    syncQueue.enqueued.clear(); // simulate a completed sync

    expect(await repository.canDeleteLocalParcel(added!.id), isFalse);
    expect(await repository.deleteLocalParcel(added.id), isFalse);
    expect(repository.parcels, hasLength(1)); // still there, not removed
  });
}
