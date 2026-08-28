import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/holdings/logic/cubit/home_state.dart';

void main() {
  group('HomeState status counts', () {
    final DateTime now = DateTime.now();
    final List<Parcel> parcels = <Parcel>[
      const Parcel(id: 'p1', holdingId: '1', isFieldAdded: true),
      Parcel(id: 'p2', holdingId: '2', completedAt: now),
      const Parcel(id: 'p3', holdingId: '3'),
      const Parcel(id: 'p4', holdingId: '4'),
    ];

    test('addedCount counts field-added parcels', () {
      final state = HomeState(status: HomeStatus.loaded, parcels: parcels);
      expect(state.addedCount, 1);
    });

    test('completedCount/pendingCompletionCount split by completedAt', () {
      final state = HomeState(status: HomeStatus.loaded, parcels: parcels);
      expect(state.completedCount, 1);
      expect(state.pendingCompletionCount, 3);
    });

    test('modifiedCount counts only parcels present in modifiedIds', () {
      final state = HomeState(
        status: HomeStatus.loaded,
        parcels: parcels,
        modifiedIds: const <String>{'p3', 'p4'},
      );
      expect(state.modifiedCount, 2);
    });

    test('modifiedCount is 0 when modifiedIds is empty', () {
      final state = HomeState(status: HomeStatus.loaded, parcels: parcels);
      expect(state.modifiedCount, 0);
    });

    test('modifiedCount ignores ids not present among parcels', () {
      final state = HomeState(
        status: HomeStatus.loaded,
        parcels: parcels,
        modifiedIds: const <String>{'not-a-real-id'},
      );
      expect(state.modifiedCount, 0);
    });

    test('copyWith replaces modifiedIds when provided', () {
      final HomeState initial = HomeState(
        status: HomeStatus.loaded,
        parcels: parcels,
        modifiedIds: const <String>{'p1'},
      );
      final HomeState updated = initial.copyWith(modifiedIds: const <String>{'p2', 'p3'});
      expect(updated.modifiedCount, 2);
    });

    test('copyWith without modifiedIds preserves the previous value', () {
      final HomeState initial = HomeState(
        status: HomeStatus.loaded,
        parcels: parcels,
        modifiedIds: const <String>{'p1'},
      );
      final HomeState updated = initial.copyWith(status: HomeStatus.loaded);
      expect(updated.modifiedIds, const <String>{'p1'});
    });
  });
}
