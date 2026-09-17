import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/errors/exceptions.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/jazla/data/local/jazla_store.dart';
import 'package:hiyaza_finder/features/jazla/data/model/jazla.dart';
import 'package:hiyaza_finder/features/jazla/data/repo/jazla_repo_impl.dart';

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
  late JazlaRepoImpl repo;
  const String cityId = 'city-1';

  setUp(() {
    repo = JazlaRepoImpl(store: JazlaStore(store: _InMemoryKeyValueStore()));
  });

  test('create assigns a fresh id and persists the Jazla', () async {
    final Jazla created = await repo.create('جزلة الري', cityId);

    expect(created.name, 'جزلة الري');
    expect(created.cityId, cityId);
    expect(created.parcelIds, isEmpty);

    final List<Jazla> all = await repo.getAll(cityId);
    expect(all.single.id, created.id);
  });

  test('addParcel on a free parcel succeeds', () async {
    final Jazla j = await repo.create('جزلة', cityId);
    await repo.addParcel(j.id, 'p1', cityId);

    final Jazla reloaded = (await repo.getAll(cityId)).single;
    expect(reloaded.parcelIds, <String>['p1']);
  });

  test('addParcel throws CacheException when the parcel is already used',
      () async {
    final Jazla a = await repo.create('جزلة أ', cityId);
    final Jazla b = await repo.create('جزلة ب', cityId);
    await repo.addParcel(a.id, 'p1', cityId);

    expect(
      () => repo.addParcel(b.id, 'p1', cityId),
      throwsA(isA<CacheException>()),
    );
  });

  test('isParcelUsed / getJazlaContaining reflect add and remove', () async {
    final Jazla j = await repo.create('جزلة', cityId);
    expect(await repo.isParcelUsed('p1', cityId), isFalse);

    await repo.addParcel(j.id, 'p1', cityId);
    expect(await repo.isParcelUsed('p1', cityId), isTrue);
    expect((await repo.getJazlaContaining('p1', cityId))?.id, j.id);

    await repo.removeParcel(j.id, 'p1', cityId);
    expect(await repo.isParcelUsed('p1', cityId), isFalse);
    expect(await repo.getJazlaContaining('p1', cityId), isNull);
  });

  test('reorderParcels persists the exact given order', () async {
    final Jazla j = await repo.create('جزلة', cityId);
    await repo.addParcel(j.id, 'p1', cityId);
    await repo.addParcel(j.id, 'p2', cityId);
    await repo.addParcel(j.id, 'p3', cityId);

    await repo.reorderParcels(j.id, <String>['p3', 'p1', 'p2'], cityId);

    final Jazla reloaded = (await repo.getAll(cityId)).single;
    expect(reloaded.parcelIds, <String>['p3', 'p1', 'p2']);
  });

  test('rename and delete only affect the targeted Jazla', () async {
    final Jazla a = await repo.create('جزلة أ', cityId);
    final Jazla b = await repo.create('جزلة ب', cityId);

    await repo.rename(a.id, 'اسم جديد', cityId);
    List<Jazla> all = await repo.getAll(cityId);
    expect(all.firstWhere((final Jazla j) => j.id == a.id).name, 'اسم جديد');
    expect(all.firstWhere((final Jazla j) => j.id == b.id).name, 'جزلة ب');

    await repo.delete(a.id, cityId);
    all = await repo.getAll(cityId);
    expect(all.map((final Jazla j) => j.id), <String>[b.id]);
  });

  test('deleting a Jazla frees its parcels for use elsewhere', () async {
    final Jazla a = await repo.create('جزلة أ', cityId);
    await repo.addParcel(a.id, 'p1', cityId);

    await repo.delete(a.id, cityId);

    expect(await repo.isParcelUsed('p1', cityId), isFalse);
  });

  test('Jazlas and parcel usage are isolated per city', () async {
    final Jazla a = await repo.create('جزلة', 'city-1');
    await repo.addParcel(a.id, 'shared-id', 'city-1');

    final Jazla b = await repo.create('جزلة', 'city-2');
    await repo.addParcel(b.id, 'shared-id', 'city-2');

    expect(await repo.isParcelUsed('shared-id', 'city-1'), isTrue);
    expect(await repo.isParcelUsed('shared-id', 'city-2'), isTrue);
    expect(await repo.getAll('city-1'), hasLength(1));
    expect(await repo.getAll('city-2'), hasLength(1));
  });
}
