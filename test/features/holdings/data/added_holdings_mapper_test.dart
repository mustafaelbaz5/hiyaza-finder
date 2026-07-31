import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/added_holdings_mapper.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';

void main() {
  test('maps a fully-populated Parcel to the added_holdings row shape', () {
    const Parcel p = Parcel(
      holdingId: '101',
      holderName: 'محمد علي',
      ownerName: 'مالك',
      nationalId: '27204191202178',
      landNumber: '10862326',
      basinName: 'البشيط',
      feddan: 1,
      qirat: 2,
      sahm: 3,
      totalSqm: 100,
      cropType: 'قمح',
      notes: 'وضع يد',
      creditType: 'أوقاف',
      usageType: 'مباني',
      isInheritance: true,
      isDelegate: true,
    );

    final Map<String, dynamic> record = parcelToAddedHoldingsRecord(p);

    expect(record['holding_id_number'], '101');
    expect(record['holder_name'], 'محمد علي');
    expect(record['owner_name'], 'مالك');
    expect(record['national_id'], '27204191202178');
    expect(record['land_number'], '10862326');
    expect(record['basin_name'], 'البشيط');
    expect(record['feddan'], 1);
    expect(record['qirat'], 2);
    expect(record['sahm'], 3);
    expect(record['total_sqm'], 100);
    expect(record['crop_type'], 'قمح');
    expect(record['notes'], 'وضع يد');
    expect(record['credit_type'], 'أوقاف');
    expect(record['usage_type'], 'مباني');
    expect(record['is_inheritance'], isTrue);
    expect(record['is_delegate'], isTrue);
  });

  test('a blank holdingId (brand-new person) maps to a null holding_id_number', () {
    const Parcel p = Parcel(holdingId: '', holderName: 'محمد');
    final Map<String, dynamic> record = parcelToAddedHoldingsRecord(p);
    expect(record['holding_id_number'], isNull);
  });

  test('a non-empty holdingId (copied for a new parcel) is preserved', () {
    const Parcel p = Parcel(holdingId: '101', holderName: 'محمد');
    final Map<String, dynamic> record = parcelToAddedHoldingsRecord(p);
    expect(record['holding_id_number'], '101');
  });

  test('null feddan/qirat/sahm default to 0, matching the not-null DB columns', () {
    const Parcel p = Parcel(holdingId: '', holderName: 'محمد');
    final Map<String, dynamic> record = parcelToAddedHoldingsRecord(p);
    expect(record['feddan'], 0);
    expect(record['qirat'], 0);
    expect(record['sahm'], 0);
  });
}
