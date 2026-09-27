import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_editor/data/local/delegate_notes_policy.dart';

void main() {
  const Parcel parcel = Parcel(
    holdingId: '1',
    holderName: 'أحمد',
    notes: <String>['ملاحظة عادية'],
  );
  const String delegateNote = 'مفوض عنه أحمد';

  test('enabling delegate updates owner and appends one automatic note', () {
    final Parcel updated = DelegateNotesPolicy.enable(
      parcel,
      ownerName: 'محمد',
      delegateNote: delegateNote,
    );
    final Parcel repeated = DelegateNotesPolicy.enable(
      updated,
      ownerName: 'محمد',
      delegateNote: delegateNote,
    );

    expect(updated.isDelegate, isTrue);
    expect(updated.ownerName, 'محمد');
    expect(updated.notes, <String>['ملاحظة عادية', delegateNote]);
    expect(repeated.notes, <String>['ملاحظة عادية', delegateNote]);
  });

  test('disabling delegate restores the holder and removes only auto notes',
      () {
    final Parcel updated = DelegateNotesPolicy.disable(
      parcel.copyWith(
        isDelegate: true,
        ownerName: 'محمد',
        notes: <String>['ملاحظة عادية', delegateNote, 'مفوض عنه اسم آخر'],
      ),
    );

    expect(updated.isDelegate, isFalse);
    expect(updated.ownerName, 'أحمد');
    expect(updated.notes, <String>['ملاحظة عادية']);
  });
}
