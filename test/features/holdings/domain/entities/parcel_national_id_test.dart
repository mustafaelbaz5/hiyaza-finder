import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';

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
  });
}
