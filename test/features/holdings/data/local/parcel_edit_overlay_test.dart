import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/holdings/data/local/parcel_edit_overlay.dart';

void main() {
  const ParcelEditOverlay overlay = ParcelEditOverlay();

  const Parcel original = Parcel(
    id: '1',
    holdingId: '101',
    holderName: 'محمد علي',
    basinName: 'البشيط',
  );

  test('apply returns the original parcel when there is no edit', () {
    expect(overlay.apply(original, null), same(original));
  });

  test('apply overlays a saved snapshot onto the original', () {
    final Map<String, dynamic> snapshot = overlay.snapshot(
      original.copyWith(cropType: 'قمح', notes: <String>['وضع يد']),
    );
    final Parcel merged = overlay.apply(original, snapshot);

    expect(merged.cropType, 'قمح');
    expect(merged.notes, <String>['وضع يد']);
    // Never-editable fields still come from the original, not the snapshot.
    expect(merged.id, original.id);
    expect(merged.holdingId, original.holdingId);
  });

  test('snapshot -> apply round-trips every editable field', () {
    final Parcel edited = original.copyWith(
      holderName: 'احمد فريد',
      nationalId: '12345678901234',
      landNumber: '9',
      feddan: 1.0,
      qirat: 2.0,
      sahm: 3.0,
      ownerName: 'مالك اخر',
      cropType: 'ارز',
      notes: <String>['وضع يد'],
      creditType: 'أوقاف',
      isInheritance: true,
      isDelegate: true,
      usageType: 'مباني',
    );

    final Parcel merged = overlay.apply(original, overlay.snapshot(edited));

    expect(merged.holderName, edited.holderName);
    expect(merged.nationalId, edited.nationalId);
    expect(merged.landNumber, edited.landNumber);
    expect(merged.feddan, edited.feddan);
    expect(merged.qirat, edited.qirat);
    expect(merged.sahm, edited.sahm);
    expect(merged.ownerName, edited.ownerName);
    expect(merged.cropType, edited.cropType);
    expect(merged.notes, edited.notes);
    expect(merged.creditType, edited.creditType);
    expect(merged.isInheritance, isTrue);
    expect(merged.isDelegate, isTrue);
    expect(merged.usageType, edited.usageType);
  });
}
