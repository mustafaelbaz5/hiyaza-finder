import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/holdings/data/local/parcel_completion_store.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(final String key) async => values[key];

  @override
  Future<void> setString(final String key, final String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(final String key) async {
    values.remove(key);
  }
}

void main() {
  test('saves, loads, renames, and removes completion status', () async {
    final _MemoryStore memory = _MemoryStore();
    final ParcelCompletionStore store = ParcelCompletionStore(store: memory);
    final DateTime completedAt = DateTime(2026, 9, 24);

    await store.saveCompleted(
      'city-1',
      'parcel-1',
      ParcelCompletionStatus(completedAt: completedAt),
    );
    expect((await store.load('city-1'))['parcel-1']!.completedAt, completedAt);

    await store.renameParcelId('city-1', 'parcel-1', 'parcel-2');
    expect((await store.load('city-1'))['parcel-1'], isNull);
    expect((await store.load('city-1'))['parcel-2']!.completedAt, completedAt);

    await store.remove('city-1', 'parcel-2');
    expect(await store.load('city-1'), isEmpty);
  });
}
