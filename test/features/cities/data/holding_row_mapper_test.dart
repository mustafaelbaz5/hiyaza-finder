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

  group('addedHoldingRowToParcel', () {
    test('maps a full added_holdings row, including the in-app-only fields', () {
      final Parcel p = addedHoldingRowToParcel(<String, dynamic>{
        'id': 'added-uuid-1',
        'holding_id_number': null, // brand-new person, no number yet
        'holder_name': 'محمد الجديد',
        'owner_name': 'مالك',
        'national_id': '11111111111111',
        'land_number': '-1',
        'basin_name': 'البشيط',
        'feddan': 2,
        'qirat': 5,
        'sahm': 0,
        'crop_type': 'قمح',
        'notes': 'غير محيز',
        'credit_type': 'أوقاف',
        'usage_type': 'مباني',
        'is_inheritance': true,
        'is_delegate': false,
      });

      expect(p.id, 'added-uuid-1');
      expect(p.isHoldingIdPending, isTrue);
      expect(p.holderName, 'محمد الجديد');
      expect(p.ownerName, 'مالك');
      expect(p.nationalId, '11111111111111');
      expect(p.landNumber, '-1');
      expect(p.basinName, 'البشيط');
      expect(p.feddan, 2);
      expect(p.qirat, 5);
      expect(p.sahm, 0);
      expect(p.cropType, 'قمح');
      expect(p.notes, 'غير محيز');
      expect(p.creditType, 'أوقاف');
      expect(p.usageType, 'مباني');
      expect(p.isInheritance, isTrue);
      expect(p.isDelegate, isFalse);
    });

    test('missing credit_type/usage_type fall back to Parcel defaults', () {
      final Parcel p = addedHoldingRowToParcel(<String, dynamic>{
        'id': 'added-uuid-2',
        'holder_name': 'محمد',
      });

      expect(p.creditType, Parcel.defaultCreditType);
      expect(p.usageType, Parcel.defaultUsageType);
      expect(p.isInheritance, isFalse);
      expect(p.isDelegate, isFalse);
    });

    test(
        'a promoted person\'s holding_id_number (assigned by the '
        'dashboard) is preserved, not treated as pending', () {
      final Parcel p = addedHoldingRowToParcel(<String, dynamic>{
        'id': 'added-uuid-3',
        'holding_id_number': '205',
        'holder_name': 'محمد',
      });

      expect(p.holdingId, '205');
      expect(p.isHoldingIdPending, isFalse);
    });
  });
}
