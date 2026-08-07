import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';

void main() {
  test('toJson -> fromJson round-trips every field', () {
    final Parcel original = Parcel(
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
      sourceAddedHoldingId: 'added-uuid-1',
      personId: 'person-uuid-1',
      reviewed: true,
      reviewedAt: DateTime(2026, 1, 2, 9, 30),
      reviewedBy: 'user-uuid-1',
      completedAt: DateTime(2026, 1, 3, 10),
      completedBy: 'user-uuid-2',
      isFieldAdded: true,
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
    expect(roundTripped.sourceAddedHoldingId, original.sourceAddedHoldingId);
    expect(roundTripped.personId, original.personId);
    expect(roundTripped.reviewed, original.reviewed);
    expect(roundTripped.reviewedAt, original.reviewedAt);
    expect(roundTripped.reviewedBy, original.reviewedBy);
    expect(roundTripped.completedAt, original.completedAt);
    expect(roundTripped.completedBy, original.completedBy);
    expect(roundTripped.isFieldAdded, original.isFieldAdded);
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
    expect(p.reviewed, isFalse);
    expect(p.reviewedAt, isNull);
    expect(p.reviewedBy, isNull);
    expect(p.completedAt, isNull);
    expect(p.completedBy, isNull);
    expect(p.isFieldAdded, isFalse);
  });

  group('copyWith for reviewed*/isFieldAdded', () {
    const Parcel base = Parcel(
      holdingId: '101',
      id: 'p-1',
      reviewed: true,
      reviewedAt: null, // set below via copyWith in each test as needed
      reviewedBy: 'user-1',
    );

    test('reviewed/isFieldAdded resolve via ?? when omitted (plain bool params)', () {
      final Parcel copy = base.copyWith();
      expect(copy.reviewed, base.reviewed);
      expect(copy.isFieldAdded, base.isFieldAdded);
    });

    test('the _unset sentinel lets reviewedAt/reviewedBy be explicitly cleared to null', () {
      final Parcel withDate = base.copyWith(reviewedAt: DateTime(2026, 1, 1));
      expect(withDate.reviewedAt, DateTime(2026, 1, 1));

      final Parcel cleared = withDate.copyWith(reviewedAt: null, reviewedBy: null);
      expect(cleared.reviewedAt, isNull);
      expect(cleared.reviewedBy, isNull);
    });

    test('omitting reviewedAt/reviewedBy from copyWith leaves them unchanged', () {
      final Parcel withDate = base.copyWith(reviewedAt: DateTime(2026, 1, 1));
      final Parcel untouched = withDate.copyWith(holdingId: '202');
      expect(untouched.reviewedAt, DateTime(2026, 1, 1));
      expect(untouched.reviewedBy, base.reviewedBy);
      expect(untouched.holdingId, '202');
    });

    test('reviewed/isFieldAdded can be flipped explicitly', () {
      final Parcel unreviewed = base.copyWith(reviewed: false);
      expect(unreviewed.reviewed, isFalse);

      final Parcel fieldAdded = base.copyWith(isFieldAdded: true);
      expect(fieldAdded.isFieldAdded, isTrue);
    });
  });

  group('copyWith for completedAt/completedBy', () {
    const Parcel base = Parcel(holdingId: '101', id: 'p-1');

    test('the _unset sentinel lets completedAt/completedBy be explicitly cleared to null', () {
      final Parcel withDate = base.copyWith(
        completedAt: DateTime(2026, 1, 1),
        completedBy: 'user-1',
      );
      expect(withDate.completedAt, DateTime(2026, 1, 1));
      expect(withDate.completedBy, 'user-1');

      final Parcel cleared =
          withDate.copyWith(completedAt: null, completedBy: null);
      expect(cleared.completedAt, isNull);
      expect(cleared.completedBy, isNull);
    });

    test('omitting completedAt/completedBy from copyWith leaves them unchanged', () {
      final Parcel withDate = base.copyWith(completedAt: DateTime(2026, 1, 1));
      final Parcel untouched = withDate.copyWith(holdingId: '202');
      expect(untouched.completedAt, DateTime(2026, 1, 1));
      expect(untouched.holdingId, '202');
    });
  });

  test('fromEditableJson preserves origin and review metadata', () {
    final Parcel original = Parcel(
      id: 'p-1',
      sourceAddedHoldingId: 'added-1',
      personId: 'person-1',
      holdingId: '101',
      reviewed: true,
      reviewedAt: DateTime(2026, 1, 1),
      reviewedBy: 'user-1',
      completedAt: DateTime(2026, 1, 2),
      completedBy: 'user-2',
      isFieldAdded: true,
      pendingGroupId: 'pending-1',
      holdingsCount: 3,
    );

    final Parcel rebuilt = Parcel.fromEditableJson(
      original,
      <String, dynamic>{'holderName': 'محمد'},
    );

    expect(rebuilt.sourceAddedHoldingId, original.sourceAddedHoldingId);
    expect(rebuilt.personId, original.personId);
    expect(rebuilt.reviewed, original.reviewed);
    expect(rebuilt.reviewedAt, original.reviewedAt);
    expect(rebuilt.reviewedBy, original.reviewedBy);
    expect(rebuilt.completedAt, original.completedAt);
    expect(rebuilt.completedBy, original.completedBy);
    expect(rebuilt.isFieldAdded, original.isFieldAdded);
    expect(rebuilt.pendingGroupId, original.pendingGroupId);
    expect(rebuilt.holdingsCount, original.holdingsCount);
  });

  test(
      'associationName round-trips through toEditableJson/fromEditableJson '
      '(REFACTOR_ROADMAP.md Phase 12 — was silently dropped, a real edit-loss '
      'bug: editable in More Details since Phase 11 §4 but excluded from the '
      'edit-overlay snapshot until now)', () {
    const Parcel original = Parcel(
      id: 'p-1',
      holdingId: '101',
      associationName: 'جمعية الدير',
    );
    final Parcel edited = original.copyWith(associationName: 'جمعية جديدة');

    final Map<String, dynamic> snapshot = edited.toEditableJson();
    expect(snapshot['associationName'], 'جمعية جديدة');

    final Parcel rebuilt = Parcel.fromEditableJson(original, snapshot);
    expect(rebuilt.associationName, 'جمعية جديدة');
  });

  test(
      'fromEditableJson falls back to original.associationName for a '
      'pre-Phase-12 snapshot that never recorded it', () {
    const Parcel original = Parcel(
      id: 'p-1',
      holdingId: '101',
      associationName: 'جمعية الدير',
    );
    final Parcel rebuilt = Parcel.fromEditableJson(
      original,
      <String, dynamic>{'holderName': 'محمد'},
    );
    expect(rebuilt.associationName, 'جمعية الدير');
  });
}
