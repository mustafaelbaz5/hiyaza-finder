import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/local/credit_type_notes_sync.dart';
import 'package:hiyaza_finder/features/holdings/data/local/parcel_notes_sync.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

void main() {
  const Parcel baseParcel = Parcel(
    holdingId: '1',
    holderName: 'محمد',
  );

  test('adding the Awqaf note updates ownership', () {
    final Parcel updated = ParcelNotesSync.applyChangedNotes(
      baseParcel,
      <String>[CreditTypeNotesSync.awqafNote],
    );

    expect(updated.creditType, 'أوقاف');
    expect(updated.notes, contains(CreditTypeNotesSync.awqafNote));
  });

  test('removing the Awqaf note restores Milk ownership', () {
    final Parcel updated = ParcelNotesSync.applyChangedNotes(
      baseParcel.copyWith(
        creditType: 'أوقاف',
        notes: <String>[CreditTypeNotesSync.awqafNote],
      ),
      const <String>[],
    );

    expect(updated.creditType, Parcel.defaultCreditType);
    expect(updated.notes, isEmpty);
  });

  test('adding a reform note updates the matching reform type', () {
    const String note = 'إصلاح اشتراكي';
    final Parcel updated = ParcelNotesSync.applyChangedNotes(
      baseParcel,
      <String>[note],
    );

    expect(updated.reformType, note);
    expect(updated.notes, contains(note));
  });

  test('ordinary notes do not change ownership or reform type', () {
    final Parcel updated = ParcelNotesSync.applyChangedNotes(
      baseParcel,
      const <String>['ملاحظة عادية'],
    );

    expect(updated.creditType, Parcel.defaultCreditType);
    expect(updated.reformType, Parcel.defaultReformType);
    expect(updated.notes, const <String>['ملاحظة عادية']);
  });
}
