import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/parcel_details/data/local/copy_validation.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

void main() {
  test('non-agricultural usage can copy without crop data', () {
    const Parcel parcel = Parcel(
      holdingId: '55',
      usageType: 'مباني',
      feddan: 1,
    );

    expect(CopyValidation.canCopyAll(parcel), isTrue);
  });

  test('agricultural usage still requires a crop type for Copy All', () {
    const Parcel parcel = Parcel(
      holdingId: '55',
      usageType: 'زراعة',
      feddan: 1,
    );

    expect(CopyValidation.canCopyAll(parcel), isFalse);
  });

  test('completion remains stricter than copying an ID', () {
    const Parcel parcel = Parcel(holdingId: '55');

    expect(CopyValidation.canMarkCompleted(parcel), isFalse);
  });
}
