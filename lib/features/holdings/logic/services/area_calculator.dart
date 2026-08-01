/// Converts an area expressed in فدان/قيراط/سهم to total square metres,
/// mirroring the desktop tool's `area_calculator.py`:
/// `feddan*4200.833 + qirat*175.03 + sahm*7.29`, rounded to 2 dp.
/// Returns `null` when all three parts are empty.
class AreaCalculator {
  const AreaCalculator._();

  static const double _sqmPerFeddan = 4200.833;
  static const double _sqmPerQirat = 175.03;
  static const double _sqmPerSahm = 7.29;

  static double? totalSqm({
    final double? feddan,
    final double? qirat,
    final double? sahm,
  }) {
    if (feddan == null && qirat == null && sahm == null) return null;
    final double total =
        (feddan ?? 0) * _sqmPerFeddan + (qirat ?? 0) * _sqmPerQirat + (sahm ?? 0) * _sqmPerSahm;
    return double.parse(total.toStringAsFixed(2));
  }
}
