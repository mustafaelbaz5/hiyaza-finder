import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

void main() {
  test('uses the approved default crop options in order', () {
    expect(
      Parcel.cropTypeOptions,
      equals(<String>[
        'قمح',
        'ارز',
        'ذرة',
        'فول',
        'برسيم',
        'عنب',
        'باذنجان',
        'بسله',
        'بصل',
        'اخرى',
      ]),
    );
  });
}
