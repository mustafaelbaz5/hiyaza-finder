import '../model/parcel.dart';
import '../model/usage_type.dart';

/// Bidirectional نوع الاستخدام ↔ notes logic (APP_UPDATES_CLAUDE.md § 4.3).
/// Kept as pure functions over [Parcel] rather than methods on the entity
/// itself, since both directions need to be triggered from different
/// widgets (usage-type dropdown vs. notes field) that only share [Parcel].
class UsageTypeNotesSync {
  const UsageTypeNotesSync._();

  static const String buildingsNote = 'الأرض بها مباني';
  static const String fallowNote = 'الأرض بور أو غير مزروعة';

  /// Applies a new نوع الاستخدام: adds/removes the matching auto-note and
  /// blanks نوع المحصول/مراحل النمو when leaving زراعة.
  static Parcel applyUsageTypeChange(
    final Parcel parcel,
    final String newUsageType,
  ) {
    final UsageType type = UsageType.fromLabel(newUsageType);
    List<String> notes = parcel.notes;

    switch (type) {
      case UsageType.buildings:
        notes = _addIfAbsent(_remove(notes, fallowNote), buildingsNote);
        return parcel.copyWith(
          usageType: type.label,
          notes: notes,
          cropType: null,
          growthStages: null,
        );
      case UsageType.fallow:
        notes = _addIfAbsent(_remove(notes, buildingsNote), fallowNote);
        return parcel.copyWith(
          usageType: type.label,
          notes: notes,
          cropType: null,
          growthStages: null,
        );
      case UsageType.agricultural:
        notes = _remove(_remove(notes, buildingsNote), fallowNote);
        return parcel.copyWith(usageType: type.label, notes: notes);
    }
  }

  /// Applies a newly-added ملاحظة: switches نوع الاستخدام when the note is
  /// one of the two usage-linked ones, leaves it untouched otherwise.
  static Parcel applyNoteAdded(final Parcel parcel, final String note) {
    switch (note) {
      case buildingsNote:
        return applyUsageTypeChange(parcel, UsageType.buildings.label);
      case fallowNote:
        return applyUsageTypeChange(parcel, UsageType.fallow.label);
      default:
        return parcel.notes.contains(note)
            ? parcel
            : parcel.copyWith(notes: <String>[...parcel.notes, note]);
    }
  }

  static List<String> _addIfAbsent(final List<String> notes, final String note) =>
      notes.contains(note) ? notes : <String>[...notes, note];

  static List<String> _remove(final List<String> notes, final String note) =>
      notes.where((final String n) => n != note).toList();
}
