import '../model/parcel.dart';

/// نوع الملكية (credit cities) / نوع الإصلاح (reform cities) is no longer a
/// visible field or a Copy All line — it only ever surfaces through
/// ملاحظات (Credit/Reform Type Logic prompt). [Parcel.creditType]/
/// [Parcel.reformType] are still stored (export/dashboard keep reading
/// them), just driven by an اوقاف toggle or a quick-select note instead of
/// a dropdown the user edits directly.
class CreditTypeNotesSync {
  const CreditTypeNotesSync._();

  static const String awqafNote = 'الأرض تابعة لهيئة الأوقاف المصرية';

  /// The اوقاف toggle for a credit city — ملك (default) removes the note,
  /// أوقاف adds it. Mirrors `UsageTypeNotesSync.applyUsageTypeChange`'s
  /// shape.
  static Parcel applyOwnershipToggle(final Parcel parcel, final bool isAwqaf) {
    final String newCreditType = isAwqaf ? 'أوقاف' : Parcel.defaultCreditType;
    final List<String> notes = isAwqaf
        ? _addIfAbsent(parcel.notes, awqafNote)
        : _remove(parcel.notes, awqafNote);
    return parcel.copyWith(creditType: newCreditType, notes: notes);
  }

  /// A reform city's نوع الإصلاح dropdown ([Parcel.reformTypeOptions]) —
  /// each option sets [Parcel.reformType] to match and, other than the
  /// default إصلاح مُملك, also adds itself as a plain ملاحظات entry (not a
  /// separate Copy All field) — reform type has no separate toggle, the
  /// note *is* the selection. Picking إصلاح مُملك removes every other
  /// reform-type note and adds nothing itself, since it never needs to
  /// appear in ملاحظات.
  static Parcel applyReformNoteSelected(final Parcel parcel, final String note) {
    if (!Parcel.reformTypeOptions.contains(note)) {
      return parcel.notes.contains(note)
          ? parcel
          : parcel.copyWith(notes: <String>[...parcel.notes, note]);
    }

    List<String> notes = parcel.notes;
    for (final String option in Parcel.reformTypeOptions) {
      notes = _remove(notes, option);
    }
    if (note != Parcel.defaultReformType) {
      notes = _addIfAbsent(notes, note);
    }
    return parcel.copyWith(reformType: note, notes: notes);
  }

  /// Applies a just-removed ملاحظة: reverts نوع الائتمان to ملك if it was
  /// the أوقاف note, or نوع الإصلاح to إصلاح مُملك if it was one of the
  /// reform-type notes — the field "returns to its value" the way removing
  /// the note undoes what adding it did. A no-op for any other note.
  static Parcel applyNoteRemoved(final Parcel parcel, final String note) {
    if (note == awqafNote) {
      return parcel.creditType == Parcel.defaultCreditType
          ? parcel
          : parcel.copyWith(creditType: Parcel.defaultCreditType);
    }
    if (Parcel.reformTypeOptions.contains(note)) {
      return parcel.reformType == Parcel.defaultReformType
          ? parcel
          : parcel.copyWith(reformType: Parcel.defaultReformType);
    }
    return parcel;
  }

  static List<String> _addIfAbsent(final List<String> notes, final String note) =>
      notes.contains(note) ? notes : <String>[...notes, note];

  static List<String> _remove(final List<String> notes, final String note) =>
      notes.where((final String n) => n != note).toList();
}
