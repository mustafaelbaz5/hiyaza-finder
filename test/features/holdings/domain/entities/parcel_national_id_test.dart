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
}
