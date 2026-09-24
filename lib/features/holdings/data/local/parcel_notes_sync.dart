import '../model/parcel.dart';
import 'credit_type_notes_sync.dart';
import 'usage_type_notes_sync.dart';

/// Applies one complete notes-list change and synchronizes every field whose
/// value is represented by a linked quick-pick note.
class ParcelNotesSync {
  const ParcelNotesSync._();

  static Parcel applyChangedNotes(
    final Parcel parcel,
    final List<String> updatedNotes,
  ) {
    final List<String> previousNotes = parcel.notes;
    Parcel updated = parcel.copyWith(notes: List<String>.of(updatedNotes));

    for (final String removedNote in previousNotes
        .where((final String note) => !updatedNotes.contains(note))) {
      updated = CreditTypeNotesSync.isLinkedNote(removedNote)
          ? CreditTypeNotesSync.applyNoteRemoved(updated, removedNote)
          : UsageTypeNotesSync.applyNoteRemoved(updated, removedNote);
    }

    for (final String addedNote in updatedNotes
        .where((final String note) => !previousNotes.contains(note))) {
      updated = CreditTypeNotesSync.isLinkedNote(addedNote)
          ? CreditTypeNotesSync.applyNoteAdded(updated, addedNote)
          : UsageTypeNotesSync.applyNoteAdded(updated, addedNote);
    }

    return updated;
  }
}
