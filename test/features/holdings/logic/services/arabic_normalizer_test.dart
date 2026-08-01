import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/logic/services/arabic_normalizer.dart';

void main() {
  group('ArabicNormalizer.normalize', () {
    test('maps ى to ي', () {
      expect(ArabicNormalizer.normalize('مصطفى'), 'مصطفي');
    });

    test('maps أ إ آ to ا', () {
      expect(ArabicNormalizer.normalize('أحمد إبراهيم آدم'), 'احمد ابراهيم ادم');
    });

    test('strips diacritics', () {
      expect(ArabicNormalizer.normalize('مُحَمَّد'), 'محمد');
    });

    test('does not map ة to ه', () {
      expect(ArabicNormalizer.normalize('فاطمة'), 'فاطمة');
    });

    test('collapses whitespace and trims', () {
      expect(ArabicNormalizer.normalize('  محمد    أحمد  '), 'محمد احمد');
    });

    test('empty string stays empty', () {
      expect(ArabicNormalizer.normalize(''), '');
    });
  });
}
