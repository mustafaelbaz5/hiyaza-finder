import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/holdings/data/local/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/holdings/data/repo/holdings_repository.dart';

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

void main() {
  late HoldingsRepository repository;

  setUp(() async {
    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
    );
  });

  test('returns null when the parcel is not in the active dataset', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
    final Parcel? result =
        await repository.setParcelCompleted('missing-id', completed: true);
    expect(result, isNull);
  });

  test('marks a holdings-origin (isFieldAdded: false) parcel completed locally', () async {
    const Parcel parcel = Parcel(id: 'p-1', holdingId: '101');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    final Parcel? updated = await repository.setParcelCompleted('p-1', completed: true);

    expect(updated, isNotNull);
    expect(updated!.completedAt, isNotNull);
    expect(repository.parcels.single.completedAt, isNotNull);
  });

  test('marks an added_holdings-origin (isFieldAdded: true) parcel completed locally', () async {
    const Parcel parcel = Parcel(id: 'p-2', holdingId: '102', isFieldAdded: true);
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    final Parcel? updated = await repository.setParcelCompleted('p-2', completed: true);

    expect(updated, isNotNull);
    expect(updated!.completedAt, isNotNull);
  });

  test('finish then un-finish results in a final local state that is not completed', () async {
    const Parcel parcel = Parcel(id: 'p-3', holdingId: '103');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    await repository.setParcelCompleted('p-3', completed: true);
    await repository.setParcelCompleted('p-3', completed: false);

    final Parcel finalState = repository.parcels.single;
    expect(finalState.completedAt, isNull);
    expect(finalState.completedBy, isNull);
  });
}
