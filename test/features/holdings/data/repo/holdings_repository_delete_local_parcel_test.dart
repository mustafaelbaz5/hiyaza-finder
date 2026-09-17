import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/holdings/data/local/local_added_parcels_store.dart';
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
      addedParcelsStore: LocalAddedParcelsStore(store: store),
    );
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  });

  test('a field-added parcel is deleted locally', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(await repository.deleteLocalParcel(added!.id), isTrue);
    expect(repository.parcels, isEmpty);
  });

  test('an imported (not field-added) holding cannot be deleted', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[
      Parcel(id: 'imported-1', holdingId: '101', isFieldAdded: false),
    ]);

    expect(await repository.deleteLocalParcel('imported-1'), isFalse);
    expect(repository.parcels, hasLength(1));
  });

  test('a missing id is a no-op and returns false', () async {
    expect(await repository.deleteLocalParcel('missing-id'), isFalse);
  });

  test('deleting one parcel does not remove an unrelated parcel', () async {
    final Parcel? parcelA = await repository.addLocalParcel(
      const Parcel(holdingId: '-1', holderName: 'محمد', landNumber: '-1'),
    );
    final Parcel? parcelB = await repository.addLocalParcel(
      const Parcel(holdingId: '-2', holderName: 'أحمد', landNumber: '-1'),
    );

    expect(await repository.deleteLocalParcel(parcelA!.id), isTrue);

    expect(repository.parcels, hasLength(1));
    expect(repository.parcels.single.id, parcelB!.id);
  });

  test(
      'deleting a sibling parcel decrements holdingsCount for the '
      'remaining parcels sharing the same holding', () async {
    final Parcel? parcelA = await repository.addLocalParcel(
      const Parcel(holdingId: '-1', holderName: 'محمد', landNumber: '-1'),
    );
    final Parcel? parcelB = await repository.addLocalParcel(
      const Parcel(
        holdingId: '-1',
        holderName: 'محمد',
        landNumber: '-1',
        holdingsCount: 2,
      ),
      parentHoldingId: parcelA!.id,
    );

    await repository.deleteLocalParcel(parcelB!.id);

    expect(repository.parcels.single.holdingsCount, 1);
  });
}
