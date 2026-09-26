import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

/// Applies notes that describe the local-only identity of a newly added
/// person. These notes are mutually exclusive and are never applied to
/// imported records.
class LocalHoldingNotePolicy {
  const LocalHoldingNotePolicy._();

  static const String unregisteredNationalId = '11111111111111';
  static const String unregisteredHoldingNote = 'الحيازة غير مسجل علي المنظومة';
  static const String unregisteredParcelNote = 'غير محيز';

  static List<String> apply({
    required final Parcel parcel,
    final Parcel? parent,
    final bool forceUnregistered = false,
  }) {
    final String? nationalId =
        parcel.nationalId?.trim() ?? parent?.nationalId?.trim();
    final bool isUnregistered =
        forceUnregistered || nationalId == unregisteredNationalId;
    if (!isUnregistered) return parcel.notes;

    final List<String> notes = parcel.notes
        .where(
          (final String note) =>
              note != unregisteredHoldingNote && note != unregisteredParcelNote,
        )
        .toList();
    notes.add(
      parcel.isZeroHoldingId ? unregisteredParcelNote : unregisteredHoldingNote,
    );
    return notes;
  }
}
