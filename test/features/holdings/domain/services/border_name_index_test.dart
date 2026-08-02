import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/domain/services/border_name_index.dart';
import 'package:hiyaza_finder/features/holdings/logic/services/arabic_normalizer.dart';

void main() {
  group('BorderNameIndex.empty', () {
    test('lookup always returns null', () {
      final BorderNameIndex index = BorderNameIndex.empty();
      expect(index.lookup(ArabicNormalizer.normalize('أي اسم')), isNull);
    });
  });

  group('BorderNameIndex.build', () {
    test('indexes by حائز name', () {
      const Parcel p = Parcel(id: '1', holdingId: '101', holderName: 'محمد علي');
      final BorderNameIndex index = BorderNameIndex.build(<Parcel>[p]);
      final Parcel? match = index.lookup(ArabicNormalizer.normalize('محمد علي'));
      expect(match?.id, '1');
    });

    test('indexes by مالك name independently of حائز', () {
      const Parcel p = Parcel(
        id: '1',
        holdingId: '101',
        holderName: 'ورثة فلان',
        ownerName: 'خالد سعيد',
      );
      final BorderNameIndex index = BorderNameIndex.build(<Parcel>[p]);
      expect(index.lookup(ArabicNormalizer.normalize('خالد سعيد'))?.id, '1');
      expect(index.lookup(ArabicNormalizer.normalize('ورثة فلان'))?.id, '1');
    });

    test('lookup key must already be normalized — raw text does not match', () {
      // e.g. hamza variants (أ/إ/آ vs ا) are only equivalent after
      // normalization; the index itself does no normalization on lookup.
      const Parcel p = Parcel(id: '1', holdingId: '101', holderName: 'أحمد فريد');
      final BorderNameIndex index = BorderNameIndex.build(<Parcel>[p]);
      expect(index.lookup('أحمد فريد'), isNull); // raw, unnormalized
      expect(index.lookup(ArabicNormalizer.normalize('احمد فريد')), isNotNull);
    });

    test('does not index blank or whitespace-only names', () {
      const Parcel p = Parcel(id: '1', holdingId: '101', holderName: '   ');
      final BorderNameIndex index = BorderNameIndex.build(<Parcel>[p]);
      expect(index.lookup(''), isNull);
    });

    test('multiple parcels of the same holding under the same name resolve to one entry', () {
      final List<Parcel> parcels = <Parcel>[
        const Parcel(id: '1', holdingId: '101', holderName: 'محمد علي'),
        const Parcel(id: '2', holdingId: '101', holderName: 'محمد علي'),
      ];
      final BorderNameIndex index = BorderNameIndex.build(parcels);
      final Parcel? match = index.lookup(ArabicNormalizer.normalize('محمد علي'));
      expect(match, isNotNull);
      expect(match!.holdingId, '101');
    });

    test(
      'ambiguous name across different holdings resolves to the holding with the most parcels',
      () {
        final List<Parcel> parcels = <Parcel>[
          const Parcel(id: 'a1', holdingId: '201', holderName: 'علي حسن'),
          const Parcel(id: 'a2', holdingId: '202', holderName: 'علي حسن'),
          const Parcel(id: 'a3', holdingId: '202', holderName: 'علي حسن'),
        ];
        final BorderNameIndex index = BorderNameIndex.build(parcels);
        final Parcel? match = index.lookup(ArabicNormalizer.normalize('علي حسن'));
        expect(match?.holdingId, '202');
      },
    );

    test('ambiguous name with tied holding sizes resolves to the first-encountered holding', () {
      final List<Parcel> parcels = <Parcel>[
        const Parcel(id: 'b1', holdingId: '301', holderName: 'محمود سيد'),
        const Parcel(id: 'b2', holdingId: '302', holderName: 'محمود سيد'),
      ];
      final BorderNameIndex index = BorderNameIndex.build(parcels);
      expect(index.lookup(ArabicNormalizer.normalize('محمود سيد'))?.holdingId, '301');
    });

    test('pending (not-yet-numbered) holdings are distinguished by groupKey, not holdingId', () {
      // Two different brand-new people sharing the "-" placeholder
      // holdingId — grouping by raw holdingId would incorrectly merge them
      // into a single fake "holding" for the size tie-break.
      final List<Parcel> parcels = <Parcel>[
        const Parcel(id: 'p1', holdingId: '-', holderName: 'زيد فهمي'),
        const Parcel(id: 'p2', holdingId: '-', holderName: 'زيد فهمي'),
        const Parcel(id: 'p3', holdingId: '-', holderName: 'زيد فهمي'),
      ];
      final BorderNameIndex index = BorderNameIndex.build(parcels);
      final Parcel? match = index.lookup(ArabicNormalizer.normalize('زيد فهمي'));
      // Each pending parcel is its own groupKey ('pending:p1', 'pending:p2',
      // 'pending:p3') — every one has exactly 1 parcel, so this is a 3-way
      // tie broken by first-encountered (p1), not a false 3-parcel holding.
      expect(match?.id, 'p1');
    });
  });
}
