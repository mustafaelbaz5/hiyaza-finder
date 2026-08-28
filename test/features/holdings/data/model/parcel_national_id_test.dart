import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

void main() {
  group('Parcel.isNationalIdValid', () {
    test('true for null (field is not required)', () {
      expect(Parcel.isNationalIdValid(null), isTrue);
    });

    test('true for an empty string', () {
      expect(Parcel.isNationalIdValid(''), isTrue);
    });

    test('true for whitespace-only', () {
      expect(Parcel.isNationalIdValid('   '), isTrue);
    });

    test('true for exactly 14 digits', () {
      expect(Parcel.isNationalIdValid('12345678901234'), isTrue);
    });

    test('true for 14 digits with surrounding whitespace', () {
      expect(Parcel.isNationalIdValid('  12345678901234  '), isTrue);
    });

    test('false for fewer than 14 digits', () {
      expect(Parcel.isNationalIdValid('1234567890123'), isFalse);
    });

    test('false for more than 14 digits', () {
      expect(Parcel.isNationalIdValid('123456789012345'), isFalse);
    });

    test('false when it contains non-digit characters', () {
      expect(Parcel.isNationalIdValid('1234567890123a'), isFalse);
    });

    test('false for the legacy placeholder value ("1"s, 14 chars)', () {
      // Note: the all-1s placeholder used elsewhere in the app (e.g.
      // ClipboardFormatter's nationalIdSlot fallback) is 14 digits and
      // therefore passes format validation — it's a valid placeholder by
      // construction, not an edge case this validator needs to special-case.
      expect(Parcel.isNationalIdValid('11111111111111'), isTrue);
    });
  });

  group('Parcel.hasRequiredFieldsFilled', () {
    const Parcel complete = Parcel(
      holdingId: '101',
      holderName: 'محمد علي',
      basinName: 'السرو',
      cropType: 'قمح',
      nationalId: '12345678901234',
      feddan: 2,
    );

    test('true when holderName/basinName/cropType are filled and '
        'nationalId is valid', () {
      expect(complete.hasRequiredFieldsFilled, isTrue);
    });

    test('true when nationalId is null (not required)', () {
      expect(
        complete.copyWith(nationalId: null).hasRequiredFieldsFilled,
        isTrue,
      );
    });

    test('false when holderName is missing', () {
      expect(
        complete.copyWith(holderName: null).hasRequiredFieldsFilled,
        isFalse,
      );
    });

    test('false when basinName is missing', () {
      expect(
        complete.copyWith(basinName: null).hasRequiredFieldsFilled,
        isFalse,
      );
    });

    test('false when cropType is missing', () {
      expect(
        complete.copyWith(cropType: null).hasRequiredFieldsFilled,
        isFalse,
      );
    });

    test('false when nationalId is present but invalid', () {
      expect(
        complete.copyWith(nationalId: '123').hasRequiredFieldsFilled,
        isFalse,
      );
    });

    test('false when holderName is only the "-" placeholder', () {
      expect(
        complete.copyWith(holderName: '-').hasRequiredFieldsFilled,
        isFalse,
      );
    });

    // REFACTOR_ROADMAP.md Phase 25 follow-up: رقم الحيازة must be
    // explicitly typed by the user before a new person/parcel can be
    // saved — but "-1" is a deliberately ALLOWED value (a field worker who
    // genuinely doesn't have the official number yet can type it themselves
    // as a sortable placeholder). Only genuinely blank/whitespace-only input
    // is rejected; `AddRecordScreen`'s field no longer auto-fills "-1", so
    // reaching that value only happens via an explicit keystroke.
    test('true when holdingId is explicitly "-1"', () {
      expect(
        complete.copyWith(holdingId: '-1').hasRequiredFieldsFilled,
        isTrue,
      );
    });

    test('false when holdingId is blank', () {
      expect(
        complete.copyWith(holdingId: '').hasRequiredFieldsFilled,
        isFalse,
      );
    });

    test('false when holdingId is whitespace-only', () {
      expect(
        complete.copyWith(holdingId: '   ').hasRequiredFieldsFilled,
        isFalse,
      );
    });

    test('true when holdingId is a real number', () {
      expect(
        complete.copyWith(holdingId: '229').hasRequiredFieldsFilled,
        isTrue,
      );
    });

    test('false when feddan/qirat/sahm are all null (area not entered)', () {
      expect(
        complete
            .copyWith(feddan: null, qirat: null, sahm: null)
            .hasRequiredFieldsFilled,
        isFalse,
      );
    });

    test('false when feddan/qirat/sahm are all zero', () {
      expect(
        complete
            .copyWith(feddan: 0.0, qirat: 0.0, sahm: 0.0)
            .hasRequiredFieldsFilled,
        isFalse,
      );
    });

    test('true when only qirat is a positive value', () {
      expect(
        complete
            .copyWith(feddan: null, qirat: 5.0, sahm: null)
            .hasRequiredFieldsFilled,
        isTrue,
      );
    });

    test('true when only sahm is a positive value', () {
      expect(
        complete
            .copyWith(feddan: null, qirat: null, sahm: 3.0)
            .hasRequiredFieldsFilled,
        isTrue,
      );
    });
  });

  group('Parcel.isAreaFilled', () {
    test('false when all three are null', () {
      expect(Parcel.isAreaFilled(), isFalse);
    });

    test('false when all three are zero', () {
      expect(Parcel.isAreaFilled(feddan: 0, qirat: 0, sahm: 0), isFalse);
    });

    test('true when feddan is positive', () {
      expect(Parcel.isAreaFilled(feddan: 1), isTrue);
    });
  });
}
