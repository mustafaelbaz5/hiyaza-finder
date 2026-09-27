import '../../../parcel_catalog/data/model/parcel.dart';

/// Shared delegate transitions used by add and edit flows. The localized
/// note text is supplied by the UI because this pure policy has no Flutter
/// dependency.
class DelegateNotesPolicy {
  const DelegateNotesPolicy._();

  static Parcel enable(
    final Parcel parcel, {
    required final String ownerName,
    required final String delegateNote,
  }) =>
      parcel.copyWith(
        isDelegate: true,
        ownerName: ownerName,
        notes: parcel.notes.contains(delegateNote)
            ? parcel.notes
            : <String>[...parcel.notes, delegateNote],
      );

  static Parcel disable(final Parcel parcel) => parcel.copyWith(
        isDelegate: false,
        ownerName: parcel.holderName,
        notes: parcel.notes
            .where((final String note) => !note.startsWith('مفوض عنه'))
            .toList(),
      );
}
