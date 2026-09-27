import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/parcel_add/data/local/existing_person_parcel_template.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

void main() {
  test('keeps person ownership data but clears parcel-specific fields', () {
    const Parcel source = Parcel(
      id: 'source-parcel',
      personId: 'person-1',
      holdingId: '42',
      holderName: 'أحمد محمد',
      nationalId: '12345678901234',
      ownerName: 'سعيد محمد',
      isInheritance: true,
      isDelegate: true,
      basinName: 'حوض قديم',
      basinCode: 'B-1',
      feddan: 2,
      qirat: 3,
      sahm: 4,
      totalSqm: 999,
      cropType: 'قمح',
      growthStages: 'نمو',
      usageType: 'مباني',
      holdingsCount: 2,
      notes: <String>['ملاحظة خاصة بالقطعة', 'مفوض عنه أحمد محمد'],
    );

    final Parcel template = existingPersonParcelTemplate(source);

    expect(template.personId, 'person-1');
    expect(template.holdingId, '42');
    expect(template.holderName, 'أحمد محمد');
    expect(template.nationalId, '12345678901234');
    expect(template.ownerName, 'سعيد محمد');
    expect(template.isInheritance, isTrue);
    expect(template.isDelegate, isTrue);
    expect(template.holdingsCount, 3);
    expect(template.basinName, isNull);
    expect(template.basinCode, isNull);
    expect(template.feddan, isNull);
    expect(template.qirat, isNull);
    expect(template.sahm, isNull);
    expect(template.totalSqm, isNull);
    expect(template.cropType, isNull);
    expect(template.growthStages, isNull);
    expect(template.usageType, Parcel.defaultUsageType);
    expect(template.landNumber, '0');
    expect(template.notes, <String>['مفوض عنه أحمد محمد']);
  });
}
