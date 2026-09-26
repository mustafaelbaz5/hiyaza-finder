import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/data/local_json_store.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';

class _MemoryStore implements KeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(final String key) async => values[key];

  @override
  Future<void> remove(final String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(final String key, final String value) async {
    values[key] = value;
  }
}

void main() {
  late _MemoryStore memory;
  late LocalJsonStore store;

  setUp(() {
    memory = _MemoryStore();
    store = LocalJsonStore(memory);
  });

  test('round-trips a JSON map', () async {
    await store.write('key', <String, Object>{'name': 'الدير'});

    expect(await store.readMap('key'), <String, dynamic>{'name': 'الدير'});
  });

  test('keeps malformed JSON intact and reports no decoded value', () async {
    memory.values['key'] = '{broken';

    expect(await store.readMap('key'), isNull);
    expect(memory.values['key'], '{broken');
  });
}
