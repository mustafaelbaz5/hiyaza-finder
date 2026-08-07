import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/parcel_status_filter.dart';

void main() {
  group('DetailScreenTab.matches', () {
    const Parcel imported = Parcel(id: 'p1', holdingId: '1');
    const Parcel added = Parcel(id: 'p2', holdingId: '2', isFieldAdded: true);
    final Parcel completed =
        Parcel(id: 'p3', holdingId: '3', completedAt: DateTime.now());
    const Parcel pending = Parcel(id: 'p4', holdingId: '4');

    test('all matches everything', () {
      expect(DetailScreenTab.all.matches(imported), isTrue);
      expect(DetailScreenTab.all.matches(added), isTrue);
      expect(DetailScreenTab.all.matches(completed), isTrue);
    });

    test('added matches field-added parcels', () {
      expect(DetailScreenTab.added.matches(added), isTrue);
      expect(DetailScreenTab.added.matches(imported), isFalse);
    });

    test(
      'added also matches a parcel identified only by sourceAddedHoldingId',
      () {
        const Parcel promoted = Parcel(
          id: 'p5',
          holdingId: '5',
          sourceAddedHoldingId: 'src-1',
        );
        expect(DetailScreenTab.added.matches(promoted), isTrue);
      },
    );

    test('reviewed matches only parcels with completedAt set', () {
      expect(DetailScreenTab.reviewed.matches(completed), isTrue);
      expect(DetailScreenTab.reviewed.matches(pending), isFalse);
    });
  });

  group('compareParcelsForDisplay', () {
    const Parcel original = Parcel(id: 'o1', holdingId: '1');
    const Parcel addedParcel =
        Parcel(id: 'a1', holdingId: '2', isFieldAdded: true);
    final Parcel reviewedOriginal =
        Parcel(id: 'ro1', holdingId: '3', completedAt: DateTime.now());
    final Parcel reviewedAdded = Parcel(
      id: 'ra1',
      holdingId: '4',
      isFieldAdded: true,
      completedAt: DateTime.now(),
    );

    test('original parcels sort before added parcels', () {
      final List<Parcel> sorted = [addedParcel, original]
        ..sort(compareParcelsForDisplay);
      expect(sorted, [original, addedParcel]);
    });

    test('reviewed parcels sort last regardless of origin', () {
      final List<Parcel> sorted = [
        reviewedOriginal,
        addedParcel,
        original,
        reviewedAdded,
      ]..sort(compareParcelsForDisplay);
      expect(sorted, [original, addedParcel, reviewedOriginal, reviewedAdded]);
    });
  });
}
