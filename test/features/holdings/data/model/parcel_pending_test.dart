import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

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

    test('false for a literal "0" — distinct from the pending placeholders',
        () {
      const Parcel p = Parcel(id: '1', holdingId: '0');
      expect(p.isHoldingIdPending, isFalse);
    });
  });

  group('isHoldingIdMissingOrZero', () {
    test('true for everything isHoldingIdPending already covers', () {
      for (final String value in <String>['', '   ', '-', '-1']) {
        expect(
          Parcel(id: '1', holdingId: value).isHoldingIdMissingOrZero,
          isTrue,
          reason: 'holdingId="$value"',
        );
      }
    });

    test('true for a literal "0"', () {
      const Parcel p = Parcel(id: '1', holdingId: '0');
      expect(p.isHoldingIdMissingOrZero, isTrue);
    });

    test('true for "0" with surrounding whitespace', () {
      const Parcel p = Parcel(id: '1', holdingId: ' 0 ');
      expect(p.isHoldingIdMissingOrZero, isTrue);
    });

    test('false for a real holding number, including one containing a 0',
        () {
      expect(
        const Parcel(id: '1', holdingId: '101').isHoldingIdMissingOrZero,
        isFalse,
      );
      expect(
        const Parcel(id: '2', holdingId: '10').isHoldingIdMissingOrZero,
        isFalse,
      );
      expect(
        const Parcel(id: '3', holdingId: '00').isHoldingIdMissingOrZero,
        isFalse,
      );
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

  group('isCurrentlyInAddedHoldings (REFACTOR_ROADMAP.md Phase 25 follow-up)', () {
    test(
        'false for a genuine import — isFieldAdded false short-circuits '
        'regardless of sourceAddedHoldingId', () {
      const Parcel imported = Parcel(id: 'h1', holdingId: '101', isFieldAdded: false);
      expect(imported.isCurrentlyInAddedHoldings, isFalse);
    });

    test(
        'true for a brand-new, not-yet-synced field-added parcel — '
        'sourceAddedHoldingId is null', () {
      const Parcel brandNew = Parcel(
        id: 'client-generated-id',
        holdingId: '-1',
        isFieldAdded: true,
      );
      expect(brandNew.isCurrentlyInAddedHoldings, isTrue);
    });

    test(
        'true for a synced-but-not-yet-promoted added_holdings row — '
        'sourceAddedHoldingId equals its own id', () {
      const Parcel addedRow = Parcel(
        id: 'added-holdings-id',
        holdingId: '-1',
        isFieldAdded: true,
        sourceAddedHoldingId: 'added-holdings-id',
      );
      expect(addedRow.isCurrentlyInAddedHoldings, isTrue);
    });

    test(
        'false for a promoted row — id has moved on from '
        'sourceAddedHoldingId, even though isFieldAdded stays true forever '
        '(REFACTOR_ROADMAP.md: holdings.is_field_added is a permanent '
        'provenance marker, not a live table-location flag)', () {
      const Parcel promoted = Parcel(
        id: 'promoted-holdings-id',
        holdingId: '788',
        isFieldAdded: true,
        sourceAddedHoldingId: 'pre-promotion-added-holdings-id',
      );
      expect(promoted.isCurrentlyInAddedHoldings, isFalse);
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
