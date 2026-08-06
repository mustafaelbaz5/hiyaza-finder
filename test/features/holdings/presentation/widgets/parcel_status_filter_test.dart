import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/parcel_status_filter.dart';

void main() {
  group('ParcelStatusFilter.matches', () {
    const Parcel imported = Parcel(id: 'p1', holdingId: '1');
    const Parcel added = Parcel(id: 'p2', holdingId: '2', isFieldAdded: true);
    final Parcel completed =
        Parcel(id: 'p3', holdingId: '3', completedAt: DateTime.now());
    const Parcel pending = Parcel(id: 'p4', holdingId: '4');

    test('all matches everything regardless of isModified', () {
      expect(ParcelStatusFilter.all.matches(imported, isModified: false), isTrue);
      expect(ParcelStatusFilter.all.matches(added, isModified: true), isTrue);
    });

    test('original matches only non-field-added parcels', () {
      expect(ParcelStatusFilter.original.matches(imported, isModified: false), isTrue);
      expect(ParcelStatusFilter.original.matches(added, isModified: false), isFalse);
    });

    test('added matches only field-added parcels', () {
      expect(ParcelStatusFilter.added.matches(added, isModified: false), isTrue);
      expect(ParcelStatusFilter.added.matches(imported, isModified: false), isFalse);
    });

    test('modified matches based on the caller-supplied isModified flag', () {
      expect(ParcelStatusFilter.modified.matches(imported, isModified: true), isTrue);
      expect(ParcelStatusFilter.modified.matches(imported, isModified: false), isFalse);
    });

    test('completed matches only parcels with completedAt set', () {
      expect(ParcelStatusFilter.completed.matches(completed, isModified: false), isTrue);
      expect(ParcelStatusFilter.completed.matches(pending, isModified: false), isFalse);
    });

    test('pending matches only parcels with completedAt null', () {
      expect(ParcelStatusFilter.pending.matches(pending, isModified: false), isTrue);
      expect(ParcelStatusFilter.pending.matches(completed, isModified: false), isFalse);
    });
  });
}
