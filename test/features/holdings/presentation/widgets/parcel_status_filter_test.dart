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

    test('added matches only field-added parcels', () {
      expect(DetailScreenTab.added.matches(added), isTrue);
      expect(DetailScreenTab.added.matches(imported), isFalse);
    });

    test('reviewed matches only parcels with completedAt set', () {
      expect(DetailScreenTab.reviewed.matches(completed), isTrue);
      expect(DetailScreenTab.reviewed.matches(pending), isFalse);
    });
  });
}
