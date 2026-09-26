import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/holdings/data/local/local_edit_tracker.dart';

class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _store = <String, String>{};
  int setStringCallCount = 0;

  @override
  Future<String?> getString(final String key) async => _store[key];

  @override
  Future<void> remove(final String key) async => _store.remove(key);

  @override
  Future<void> setString(final String key, final String value) async {
    setStringCallCount++;
    _store[key] = value;
  }
}

void main() {
  late _InMemoryKeyValueStore keyValueStore;
  late LocalEditTracker tracker;

  setUp(() {
    keyValueStore = _InMemoryKeyValueStore();
    tracker = LocalEditTracker(store: keyValueStore);
  });

  test('markEditedBatch marks every id in one round trip', () async {
    await tracker.markEditedBatch(<String>['a', 'b', 'c'], 'city-1');

    expect(keyValueStore.setStringCallCount, 1);
    expect(await tracker.getEditedIds('city-1'), <String>{'a', 'b', 'c'});
  });

  test('markEditedBatch merges with ids already marked individually', () async {
    await tracker.markEdited('a', 'city-1');
    await tracker.markEditedBatch(<String>['b', 'c'], 'city-1');

    expect(await tracker.getEditedIds('city-1'), <String>{'a', 'b', 'c'});
  });

  test('markEditedBatch with an empty iterable is a no-op', () async {
    await tracker.markEditedBatch(<String>[], 'city-1');

    expect(keyValueStore.setStringCallCount, 0);
    expect(await tracker.getEditedIds('city-1'), isEmpty);
  });

  test('markEditedBatch does far fewer store writes than one call per id',
      () async {
    final List<String> ids = List<String>.generate(500, (final i) => 'p$i');

    await tracker.markEditedBatch(ids, 'city-1');

    // The whole point of batching: 500 ids marked in exactly 1 write, not
    // 500 — this is the fix for the bulk-edit freeze (one SharedPreferences
    // round trip per parcel was the actual bottleneck).
    expect(keyValueStore.setStringCallCount, 1);
    expect((await tracker.getEditedIds('city-1')).length, 500);
  });
}
