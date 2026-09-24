import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/local/local_holding_note_policy.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

void main() {
  test('zero uses غير محيز and removes the other automatic note', () {
    const Parcel parcel = Parcel(
      id: 'p1',
      holdingId: '0',
      nationalId: LocalHoldingNotePolicy.unregisteredNationalId,
      notes: <String>[LocalHoldingNotePolicy.unregisteredHoldingNote],
    );

    expect(
      LocalHoldingNotePolicy.apply(parcel: parcel),
      <String>[LocalHoldingNotePolicy.unregisteredParcelNote],
    );
  });

  test('a missing non-zero holding uses the unregistered note', () {
    const Parcel parcel = Parcel(
      id: 'p1',
      holdingId: '-1',
      nationalId: LocalHoldingNotePolicy.unregisteredNationalId,
      notes: <String>[LocalHoldingNotePolicy.unregisteredParcelNote],
    );

    expect(
      LocalHoldingNotePolicy.apply(parcel: parcel),
      <String>[LocalHoldingNotePolicy.unregisteredHoldingNote],
    );
  });

  test('a confirmed national id does not add automatic notes', () {
    const Parcel parcel = Parcel(id: 'p1', holdingId: '0', nationalId: '123');
    expect(LocalHoldingNotePolicy.apply(parcel: parcel), isEmpty);
  });
}
