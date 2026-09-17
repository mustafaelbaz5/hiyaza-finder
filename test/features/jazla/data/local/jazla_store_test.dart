import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/jazla/data/local/jazla_store.dart';
import 'package:hiyaza_finder/features/jazla/data/model/jazla.dart';

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
  late _InMemoryKeyValueStore keyValueStore;
  late JazlaStore store;

  setUp(() {
    keyValueStore = _InMemoryKeyValueStore();
    store = JazlaStore(store: keyValueStore);
  });

  test('load returns an empty list when nothing has been saved', () async {
    expect(await store.load('city-1'), isEmpty);
  });

  test('save then load round-trips the full Jazla list', () async {
    final List<Jazla> jazlas = <Jazla>[
      Jazla(
        id: 'j1',
        cityId: 'city-1',
        name: 'جزلة الري',
        parcelIds: const <String>['p1', 'p2'],
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    await store.save('city-1', jazlas);
    final List<Jazla> loaded = await store.load('city-1');

    expect(loaded, jazlas);
  });

  test('saving an empty list removes the stored key instead of writing "[]"',
      () async {
    await store.save(
      'city-1',
      <Jazla>[
        Jazla(id: 'j1', cityId: 'city-1', name: 'x', createdAt: DateTime(2026)),
      ],
    );
    expect(await keyValueStore.getString('jazla::city-1'), isNotNull);

    await store.save('city-1', const <Jazla>[]);

    expect(await keyValueStore.getString('jazla::city-1'), isNull);
    expect(await store.load('city-1'), isEmpty);
  });

  test('different cities are stored under independent keys', () async {
    await store.save(
      'city-1',
      <Jazla>[
        Jazla(id: 'a', cityId: 'city-1', name: 'a', createdAt: DateTime(2026)),
      ],
    );
    await store.save(
      'city-2',
      <Jazla>[
        Jazla(id: 'b', cityId: 'city-2', name: 'b', createdAt: DateTime(2026)),
      ],
    );

    expect((await store.load('city-1')).single.id, 'a');
    expect((await store.load('city-2')).single.id, 'b');
  });
}
