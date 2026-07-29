import 'parcel.dart';

/// A per-parcel "app-added" field that can be bulk-applied across many
/// parcels at once (optionally scoped to one حوض) from the file-status
/// screen — e.g. setting نوع الزرع for every parcel in a basin in one go.
enum BulkEditableField { cropType, notes, creditType, usageType, isInheritance }

extension BulkEditableFieldX on BulkEditableField {
  String get label => switch (this) {
        BulkEditableField.cropType => 'نوع الزرع',
        BulkEditableField.notes => 'ملاحظات',
        BulkEditableField.creditType => 'نوع الائتمان',
        BulkEditableField.usageType => 'نوع الاستخدام',
        BulkEditableField.isInheritance => 'وراثة',
      };

  /// `true` for the one boolean field (وراثة) — picked via two named
  /// options instead of the free dropdown list [textOptions] provides.
  bool get isBoolean => this == BulkEditableField.isInheritance;

  /// Selectable values for text-valued fields (ignored when [isBoolean]).
  List<String> get textOptions => switch (this) {
        BulkEditableField.cropType => Parcel.cropTypeOptions,
        BulkEditableField.notes => Parcel.notesOptions,
        BulkEditableField.creditType => Parcel.creditTypeOptions,
        BulkEditableField.usageType => Parcel.usageTypeOptions,
        BulkEditableField.isInheritance => const <String>[],
      };

  /// Whether the picker offers a "—" (clear/unset) option.
  bool get allowClear =>
      this == BulkEditableField.cropType || this == BulkEditableField.notes;
}
