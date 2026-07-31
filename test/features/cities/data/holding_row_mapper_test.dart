import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/cities/data/holding_row_mapper.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';

void main() {
  test('maps a full holdings row to the equivalent Parcel', () {
    final Parcel p = holdingRowToParcel(<String, dynamic>{
      'id': 'uuid-1',
      'holding_id_number': '101',
      'page_number': '2',
      'directorate': 'الدقهلية',
      'administration': 'اجا',
      'basin_name': 'البشيط',
      'basin_code': '-1',
      'holder_name': 'محمد علي',
      'national_id': '27204191202178',
      'border_east': 'مصرف',
      'border_west': 'مروى',
      'border_south': 'محمد على شبل',
      'border_north': 'ابراهيم الشبراوى منصور',
      'land_number': '10862326',
      'feddan': 0,
      'qirat': 12,
      'sahm': 16,
      'total_sqm': 2217,
      'association_name': 'الدير -الائتمان الزراعي',
    });

    expect(p.id, 'uuid-1');
    expect(p.holdingId, '101');
    expect(p.pageNumber, '2');
    expect(p.directorate, 'الدقهلية');
    expect(p.basinName, 'البشيط');
    expect(p.holderName, 'محمد علي');
    expect(p.nationalId, '27204191202178');
    expect(p.borderEast, 'مصرف');
    expect(p.landNumber, '10862326');
    expect(p.feddan, 0);
    expect(p.qirat, 12);
    expect(p.sahm, 16);
    expect(p.totalSqm, 2217);
    expect(p.associationName, 'الدير -الائتمان الزراعي');
  });

  test('a null holding_id_number becomes an empty string, not null', () {
    final Parcel p = holdingRowToParcel(<String, dynamic>{
      'id': 'uuid-2',
      'holding_id_number': null,
    });
    expect(p.holdingId, '');
  });

  test('fractional numeric columns survive the double conversion', () {
    final Parcel p = holdingRowToParcel(<String, dynamic>{
      'id': 'uuid-3',
      'holding_id_number': '42',
      'total_sqm': 2260.74,
    });
    expect(p.totalSqm, 2260.74);
  });

  test('a null numeric column stays null, not zero', () {
    final Parcel p = holdingRowToParcel(<String, dynamic>{
      'id': 'uuid-4',
      'holding_id_number': '42',
      'feddan': null,
    });
    expect(p.feddan, isNull);
  });
}
