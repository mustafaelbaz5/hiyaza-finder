import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';

void main() {
  test('toJson -> fromJson round-trips every field', () {
    const Parcel original = Parcel(
      id: 'uuid-1',
      holdingId: '101',
      pageNumber: '2',
      directorate: 'الدقهلية',
      administration: 'اجا',
      basinName: 'البشيط',
      basinCode: '-1',
      holderName: 'محمد علي',
      nationalId: '27204191202178',
      borderEast: 'مصرف',
      borderSouth: 'محمد على شبل',
      borderWest: 'مروى',
      borderNorth: 'ابراهيم الشبراوى منصور',
      landNumber: '10862326',
      feddan: 0,
      qirat: 12,
      sahm: 16,
      totalSqm: 2217.5,
      ownerName: 'مالك',
      associationName: 'الدير -الائتمان الزراعي',
      cropType: 'قمح',
      notes: 'وضع يد',
      creditType: 'أوقاف',
      isInheritance: true,
      isDelegate: true,
      usageType: 'مباني',
    );

    final Parcel roundTripped = Parcel.fromJson(original.toJson());

    expect(roundTripped.id, original.id);
    expect(roundTripped.holdingId, original.holdingId);
    expect(roundTripped.pageNumber, original.pageNumber);
    expect(roundTripped.directorate, original.directorate);
    expect(roundTripped.basinName, original.basinName);
    expect(roundTripped.holderName, original.holderName);
    expect(roundTripped.nationalId, original.nationalId);
    expect(roundTripped.borderEast, original.borderEast);
    expect(roundTripped.borderSouth, original.borderSouth);
    expect(roundTripped.borderWest, original.borderWest);
    expect(roundTripped.borderNorth, original.borderNorth);
    expect(roundTripped.landNumber, original.landNumber);
    expect(roundTripped.feddan, original.feddan);
    expect(roundTripped.qirat, original.qirat);
    expect(roundTripped.sahm, original.sahm);
    expect(roundTripped.totalSqm, original.totalSqm);
    expect(roundTripped.ownerName, original.ownerName);
    expect(roundTripped.associationName, original.associationName);
    expect(roundTripped.cropType, original.cropType);
    expect(roundTripped.notes, original.notes);
    expect(roundTripped.creditType, original.creditType);
    expect(roundTripped.isInheritance, original.isInheritance);
    expect(roundTripped.isDelegate, original.isDelegate);
    expect(roundTripped.usageType, original.usageType);
  });

  test('fromJson defaults missing optional fields correctly', () {
    final Parcel p = Parcel.fromJson(<String, dynamic>{
      'holdingId': '55',
    });
    expect(p.id, '');
    expect(p.holdingId, '55');
    expect(p.creditType, Parcel.defaultCreditType);
    expect(p.usageType, Parcel.defaultUsageType);
    expect(p.isInheritance, isFalse);
    expect(p.isDelegate, isFalse);
  });
}
