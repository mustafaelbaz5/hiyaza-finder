import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';

/// Covers `HoldingsRepository.findByBorderText`'s O(1) precomputed-index
/// behavior — specifically that the index used for lookups is rebuilt
/// whenever the active dataset changes (city load, single-field edit,
/// adding a new parcel/person), so a stale index never serves a wrong or
/// missing navigation target. `ParcelQueryService`/`BorderNameIndex` cover
/// the pure matching/tie-break logic in isolation; this file covers the
/// repository's responsibility of keeping the index in sync with mutations.
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

  setUp(() {
    repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
    );
  });

  test('finds a match immediately after loadParcelsForCity', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[
      Parcel(id: '1', holdingId: '101', holderName: 'محمد علي'),
    ]);

    final Parcel? match = repository.findByBorderText('محمد على');
    expect(match?.id, '1');
  });

  test('loading a new city replaces the previous city\'s index entirely', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[
      Parcel(id: '1', holdingId: '101', holderName: 'محمد علي'),
    ]);
    expect(repository.findByBorderText('محمد علي'), isNotNull);

    await repository.loadParcelsForCity('city-2', const <Parcel>[
      Parcel(id: '2', holdingId: '201', holderName: 'سعيد فهمي'),
    ]);

    // The first city's person is no longer resolvable once a different
    // city is active — the index must not leak entries across cities.
    expect(repository.findByBorderText('محمد علي'), isNull);
    expect(repository.findByBorderText('سعيد فهمي')?.id, '2');
  });

  test('a renamed حائز is resolvable by the new name after updateParcel', () async {
    const Parcel original = Parcel(id: '1', holdingId: '101', holderName: 'محمد علي');
    await repository.loadParcelsForCity('city-1', const <Parcel>[original]);

    await repository.updateParcel(original.copyWith(holderName: 'محمد سعيد'));

    // Old name no longer resolves — the index reflects the correction,
    // not a stale snapshot from load time.
    expect(repository.findByBorderText('محمد علي'), isNull);
    expect(repository.findByBorderText('محمد سعيد')?.id, '1');
  });

  test('a newly added person becomes navigable via findByBorderText immediately', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);

    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '-', holderName: 'خالد إبراهيم'),
    );

    expect(added, isNotNull);
    expect(repository.findByBorderText('خالد ابراهيم')?.id, added!.id);
  });

  test('returns null before any city has been loaded', () {
    final HoldingsRepository fresh = HoldingsRepository(
      editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
    );
    expect(fresh.findByBorderText('أي اسم'), isNull);
  });
}
