import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/holdings/data/local/arabic_normalizer.dart';
import 'package:hiyaza_finder/features/holdings/data/local/parcel_dataset_state.dart';
import 'package:hiyaza_finder/features/holdings/data/local/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

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
  late ParcelDatasetState state;
  late _InMemoryKeyValueStore store;

  setUp(() {
    store = _InMemoryKeyValueStore();
    state = ParcelDatasetState(editsStore: ParcelEditsStore(store: store));
  });

  group('adopt', () {
    test('replaces the active dataset and city metadata', () async {
      const List<Parcel> parcels = <Parcel>[
        Parcel(id: '1', holdingId: '101', holderName: 'محمد'),
        Parcel(id: '2', holdingId: '102', holderName: 'أحمد'),
      ];
      final List<Parcel> result = await state.adopt(
        'city-1',
        parcels,
        cityName: 'الدير',
      );

      expect(result, hasLength(2));
      expect(state.parcels, hasLength(2));
      expect(state.activeCityId, 'city-1');
      expect(state.activeCityName, 'الدير');
    });

    test('reapplies previously-persisted edits on load', () async {
      const Parcel original = Parcel(id: '1', holdingId: '101', holderName: 'محمد');
      // First adopt + edit + persist.
      await state.adopt('city-1', const <Parcel>[original]);
      state.setEdit('1', original.copyWith(holderName: 'محمد المعدّل').toEditableJson());
      await state.persistEdits();

      // Fresh state instance simulating a new app session loading the same city.
      final ParcelDatasetState reloaded =
          ParcelDatasetState(editsStore: ParcelEditsStore(store: store));
      await reloaded.adopt('city-1', const <Parcel>[original]);

      expect(reloaded.parcels.single.holderName, 'محمد المعدّل');
    });

    test('rebuilds the border index from the adopted parcels', () async {
      const Parcel p = Parcel(
        id: '1',
        holdingId: '101',
        holderName: 'محمد',
        borderNorth: 'محمد',
      );
      await state.adopt('city-1', const <Parcel>[p]);

      expect(
        state.borderIndex.lookup(ArabicNormalizer.normalize('محمد')),
        isNotNull,
      );
    });
  });

  group('edit overlay bookkeeping', () {
    test('isParcelEdited is false until an edit is set', () async {
      const Parcel p = Parcel(id: '1', holdingId: '101');
      await state.adopt('city-1', const <Parcel>[p]);

      expect(state.isParcelEdited('1'), isFalse);
      state.setEdit('1', p.toEditableJson());
      expect(state.isParcelEdited('1'), isTrue);
    });

    test('removeEdit clears a previously-set edit', () async {
      const Parcel p = Parcel(id: '1', holdingId: '101');
      await state.adopt('city-1', const <Parcel>[p]);
      state.setEdit('1', p.toEditableJson());

      state.removeEdit('1');

      expect(state.isParcelEdited('1'), isFalse);
    });

    test('applyPayload merges a payload onto an original parcel', () {
      const Parcel original = Parcel(id: '1', holdingId: '101', notes: 'قديم');
      final Parcel merged = state.applyPayload(
        original,
        original.copyWith(notes: 'جديد').toEditableJson(),
      );

      expect(merged.notes, 'جديد');
    });
  });

  group('original-value tracking', () {
    test('originalParcel returns the value from adopt before any edit', () async {
      const Parcel p = Parcel(id: '1', holdingId: '101', holderName: 'محمد');
      await state.adopt('city-1', const <Parcel>[p]);

      expect(state.originalParcel('1')?.holderName, 'محمد');
    });

    test('setOriginal overrides the tracked original value', () async {
      const Parcel p = Parcel(id: '1', holdingId: '101');
      await state.adopt('city-1', const <Parcel>[p]);

      state.setOriginal('1', p.copyWith(holderName: 'من الخادم'));

      expect(state.originalParcel('1')?.holderName, 'من الخادم');
    });

    test('removeOriginal drops the tracked value', () async {
      const Parcel p = Parcel(id: '1', holdingId: '101');
      await state.adopt('city-1', const <Parcel>[p]);

      state.removeOriginal('1');

      expect(state.originalParcel('1'), isNull);
    });

    test('originalParcel is null for an id never adopted', () {
      expect(state.originalParcel('missing'), isNull);
    });
  });

  group('parcel list mutation', () {
    test('indexOf finds a parcel by id', () async {
      const List<Parcel> parcels = <Parcel>[
        Parcel(id: '1', holdingId: '101'),
        Parcel(id: '2', holdingId: '102'),
      ];
      await state.adopt('city-1', parcels);

      expect(state.indexOf('2'), 1);
      expect(state.indexOf('missing'), -1);
    });

    test('replaceAt swaps the parcel at a given index', () async {
      const List<Parcel> parcels = <Parcel>[Parcel(id: '1', holdingId: '101')];
      await state.adopt('city-1', parcels);

      state.replaceAt(0, const Parcel(id: '1', holdingId: '999'));

      expect(state.parcels.single.holdingId, '999');
    });

    test('append adds a new parcel to the end of the dataset', () async {
      await state.adopt('city-1', const <Parcel>[]);

      state.append(const Parcel(id: 'new', holdingId: '-1'));

      expect(state.parcels, hasLength(1));
      expect(state.parcels.single.id, 'new');
    });

  });
}
