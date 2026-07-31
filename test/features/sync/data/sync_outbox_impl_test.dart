import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/sync/data/sync_outbox_impl.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';

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

EditHoldingOperation _op(final String id) => EditHoldingOperation(
      id: id,
      createdAt: DateTime(2026),
      cityId: 'city-1',
      holdingId: 'h-$id',
      payload: const <String, dynamic>{'notes': 'x'},
    );

void main() {
  late SyncOutboxImpl outbox;

  setUp(() {
    outbox = SyncOutboxImpl(_InMemoryKeyValueStore());
  });

  test('pending is empty for a fresh outbox', () async {
    expect(await outbox.pending(), isEmpty);
  });

  test('enqueue persists the operation, pending returns it back', () async {
    await outbox.enqueue(_op('a'));
    final List<SyncOperation> pending = await outbox.pending();
    expect(pending, hasLength(1));
    expect(pending.single.id, 'a');
  });

  test('enqueue is additive — multiple operations accumulate in order', () async {
    await outbox.enqueue(_op('a'));
    await outbox.enqueue(_op('b'));
    final List<SyncOperation> pending = await outbox.pending();
    expect(pending.map((final SyncOperation o) => o.id), <String>['a', 'b']);
  });

  test('remove drops only the matching operation', () async {
    await outbox.enqueue(_op('a'));
    await outbox.enqueue(_op('b'));
    await outbox.remove('a');
    final List<SyncOperation> pending = await outbox.pending();
    expect(pending.map((final SyncOperation o) => o.id), <String>['b']);
  });

  test('update replaces an operation with the same id (e.g. after a retry)', () async {
    await outbox.enqueue(_op('a'));
    final EditHoldingOperation bumped =
        (_op('a')).withIncrementedAttempts(DateTime(2026, 1, 2));
    await outbox.update(bumped);

    final List<SyncOperation> pending = await outbox.pending();
    expect(pending, hasLength(1));
    expect(pending.single.attempts, 1);
  });

  test('pendingCountChanges emits the new count after enqueue/remove', () async {
    final Future<List<int>> counts = outbox.pendingCountChanges.take(2).toList();
    await outbox.enqueue(_op('a'));
    await outbox.remove('a');
    expect(await counts, <int>[1, 0]);
  });
}
