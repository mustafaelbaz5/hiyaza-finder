import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/cubit/home_state.dart';

void main() {
  group('HomeState status counts', () {
    final List<Parcel> parcels = const <Parcel>[
      Parcel(id: 'p1', holdingId: '1', isFieldAdded: true, reviewed: false),
      Parcel(id: 'p2', holdingId: '2', isFieldAdded: false, reviewed: true),
      Parcel(id: 'p3', holdingId: '3', isFieldAdded: false, reviewed: false),
      Parcel(id: 'p4', holdingId: '4', isFieldAdded: false, reviewed: false),
    ];

    test('addedCount counts field-added parcels', () {
      final state = HomeState(status: HomeStatus.loaded, parcels: parcels);
      expect(state.addedCount, 1);
    });

    test('reviewedCount/pendingReviewCount split by reviewed flag', () {
      final state = HomeState(status: HomeStatus.loaded, parcels: parcels);
      expect(state.reviewedCount, 1);
      expect(state.pendingReviewCount, 3);
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
