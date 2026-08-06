import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/services/area_calculator.dart';

void main() {
  group('AreaCalculator.totalSqm', () {
    test('returns null when all parts are empty', () {
      expect(AreaCalculator.totalSqm(), isNull);
    });

    test('computes from feddan/qirat/sahm and rounds to 2 dp', () {
      // 1*4200.833 + 2*175.03 + 3*7.29 = 4572.763
      expect(
        AreaCalculator.totalSqm(feddan: 1, qirat: 2, sahm: 3),
        closeTo(4572.76, 0.001),
      );
    });

    test('treats missing parts as zero', () {
      expect(
        AreaCalculator.totalSqm(qirat: 1),
        closeTo(175.03, 0.001),
      );
    });
  });
}
