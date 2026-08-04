import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';

void main() {
  group('isHoldingIdPending', () {
    test('true for a blank holdingId', () {
      const Parcel p = Parcel(id: '1', holdingId: '');
      expect(p.isHoldingIdPending, isTrue);
    });

    test('true for a whitespace-only holdingId', () {
      const Parcel p = Parcel(id: '1', holdingId: '   ');
      expect(p.isHoldingIdPending, isTrue);
    });

    test('true for the "-" placeholder', () {
      const Parcel p = Parcel(id: '1', holdingId: '-');
      expect(p.isHoldingIdPending, isTrue);
    });

    test('true for the "-1" placeholder (the add-person form default)', () {
      const Parcel p = Parcel(id: '1', holdingId: '-1');
      expect(p.isHoldingIdPending, isTrue);
    });

    test('false for a real holding number', () {
      const Parcel p = Parcel(id: '1', holdingId: '101');
      expect(p.isHoldingIdPending, isFalse);
    });
  });

  group('groupKey', () {
    test('equals holdingId for a confirmed record', () {
      const Parcel p = Parcel(id: '1', holdingId: '101');
      expect(p.groupKey, '101');
    });

    test(
        'is derived from the unique id for a pending record, not the '
        'shared placeholder — two different new people must not collide '
        'just because neither has a real number yet', () {
      const Parcel a = Parcel(id: 'a', holdingId: '-');
      const Parcel b = Parcel(id: 'b', holdingId: '-');

      expect(a.groupKey, isNot('-'));
      expect(a.groupKey, isNot(b.groupKey));
    });
  });

  group('copyWith(holdingId:)', () {
    test('overrides holdingId when given', () {
      const Parcel p = Parcel(id: '1', holdingId: '-1');
      final Parcel updated = p.copyWith(holdingId: '205');
      expect(updated.holdingId, '205');
    });

    test('keeps the original holdingId when omitted', () {
      const Parcel p = Parcel(id: '1', holdingId: '205');
      final Parcel updated = p.copyWith(holderName: 'محمد');
      expect(updated.holdingId, '205');
    });
  });
}
