import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/local/parcel_mapper.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

void main() {
  test('maps a full parcels row to the equivalent Parcel', () {
    final Parcel p = parcelRowToParcel(<String, dynamic>{
      'id': 'uuid-1',
      'city_id': 'city-1',
      'basin_id': 'basin-1',
      'directorate': 'الدقهليه',
      'administration': 'اجا',
      'association_name': 'ديرب بقطارس-الائتمان الزراعي',
      'association_code': '323917',
      'association_type': 'agricultural_credit',
      'basin_name': 'داير الناحيه',
      'basin_code': '06323000003239000001',
      'holding_id_number': '101',
      'unified_holding_id': '',
      'registry_page': '',
      'parcel_count_in_holding': 2,
      'national_id': '27204191202178',
      'holder_name': 'محمد علي',
      'land_number': '10862326',
      'area_feddan': 0,
      'area_qirat': 12,
      'area_sahm': 16,
      'area_sqm': 2217,
      'border_north': 'ابراهيم الشبراوي منصور',
      'border_south': 'محمد علي شبل',
      'border_east': 'مصرف',
      'border_west': 'مروى',
    });

    expect(p.id, 'uuid-1');
    expect(p.holdingId, '101');
    expect(p.directorate, 'الدقهليه');
    expect(p.administration, 'اجا');
    expect(p.basinName, 'داير الناحيه');
    expect(p.basinCode, '06323000003239000001');
    expect(p.holderName, 'محمد علي');
    expect(p.nationalId, '27204191202178');
    expect(p.borderEast, 'مصرف');
    expect(p.borderWest, 'مروى');
    expect(p.borderSouth, 'محمد علي شبل');
    expect(p.borderNorth, 'ابراهيم الشبراوي منصور');
    expect(p.landNumber, '10862326');
    expect(p.feddan, 0);
    expect(p.qirat, 12);
    expect(p.sahm, 16);
    expect(p.totalSqm, 2217);
    expect(p.associationName, 'ديرب بقطارس-الائتمان الزراعي');
    expect(p.holdingsCount, 2);

    // Every field-worker-entered value is local-only on this schema — the
    // remote row never carries it, so the mapper leaves these at their
    // constructor defaults; the edit overlay fills them in afterward.
    expect(p.ownerName, isNull);
    expect(p.cropType, isNull);
    expect(p.notes, isEmpty);
    expect(p.creditType, Parcel.defaultCreditType);
    expect(p.isInheritance, isFalse);
    expect(p.isDelegate, isFalse);
  });

  test('a null holding_id_number becomes an empty string, not null', () {
    final Parcel p = parcelRowToParcel(<String, dynamic>{
      'id': 'uuid-2',
      'holding_id_number': null,
    });
    expect(p.holdingId, '');
  });

  test('fractional numeric columns survive the double conversion', () {
    final Parcel p = parcelRowToParcel(<String, dynamic>{
      'id': 'uuid-3',
      'holding_id_number': '42',
      'area_sqm': 2260.74,
    });
    expect(p.totalSqm, 2260.74);
  });

  test('a null numeric column stays null, not zero', () {
    final Parcel p = parcelRowToParcel(<String, dynamic>{
      'id': 'uuid-4',
      'holding_id_number': '42',
      'area_feddan': null,
    });
    expect(p.feddan, isNull);
  });

  test('a null parcel_count_in_holding stays null, not zero', () {
    final Parcel p = parcelRowToParcel(<String, dynamic>{
      'id': 'uuid-5',
      'holding_id_number': '42',
      'parcel_count_in_holding': null,
    });
    expect(p.holdingsCount, isNull);
  });
}
