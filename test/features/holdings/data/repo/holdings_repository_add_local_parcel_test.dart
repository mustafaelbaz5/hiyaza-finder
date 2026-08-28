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
      datasetState: null,
      editsStore: ParcelEditsStore(store: store),
      addedParcelsStore: LocalAddedParcelsStore(store: store),
    );
    // Simulate an active city (addLocalParcel is a no-op without one).
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  });

  test('returns null when no city is active', () async {
    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    final HoldingsRepository noCityRepo = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
      addedParcelsStore: LocalAddedParcelsStore(store: store),
    );
    final Parcel? result = await noCityRepo.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );
    expect(result, isNull);
  });

  test('appends the new parcel to the in-memory dataset with a fresh id', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(added, isNotNull);
    expect(added!.id, isNotEmpty);
    expect(added.sourceAddedHoldingId, added.id);
    expect(added.isFieldAdded, isTrue);
    expect(repository.parcels, hasLength(1));
    expect(repository.parcels.single.holderName, 'محمد');
  });

  test(
      'derives holderNameFarmerCard/ownerNameFarmerCard from '
      'holderName/ownerName — the fields are no longer independently '
      'user-entered', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد', ownerName: 'أحمد'),
    );

    expect(added!.holderNameFarmerCard, 'محمد');
    expect(added.ownerNameFarmerCard, 'أحمد');
  });

  test(
      'a new parcel for an existing pending person joins the same '
      'pendingGroupId as its parent', () async {
    final Parcel? parcelA = await repository.addLocalParcel(
      const Parcel(holdingId: '-1', holderName: 'Ahmed', landNumber: '-1'),
    );
    expect(parcelA, isNotNull);

    final Parcel? parcelB = await repository.addLocalParcel(
      const Parcel(holdingId: '-1', holderName: 'Ahmed', landNumber: '-1'),
      parentHoldingId: parcelA!.id,
    );
    expect(parcelB, isNotNull);

    expect(
      parcelB!.groupKey,
      parcelA.groupKey,
      reason: 'Both parcels belong to the same person and must group '
          'together in search/detail.',
    );
    expect(repository.parcels, hasLength(2));
  });

  test(
      'adding a sibling parcel bumps holdingsCount across every parcel '
      'sharing the same holding', () async {
    final Parcel? parcelA = await repository.addLocalParcel(
      const Parcel(holdingId: '-1', holderName: 'Ahmed', landNumber: '-1'),
    );

    await repository.addLocalParcel(
      const Parcel(
        holdingId: '-1',
        holderName: 'Ahmed',
        landNumber: '-1',
        holdingsCount: 2,
      ),
      parentHoldingId: parcelA!.id,
    );

    for (final Parcel p in repository.parcels) {
      expect(p.holdingsCount, 2);
    }
  });
}
