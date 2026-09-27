import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/usage_type.dart';
import 'package:hiyaza_finder/features/parcel_editor/data/local/parcel_notes_sync.dart';
import 'package:hiyaza_finder/features/parcel_editor/data/local/usage_type_notes_sync.dart';
import 'package:hiyaza_finder/features/parcel_review/data/model/bulk_editable_field.dart';

import '../model/jazla_parcel_defaults.dart';

/// Pure mapping between Jazla bulk selections and defaults for future parcels.
class JazlaParcelDefaultsPolicy {
  const JazlaParcelDefaultsPolicy._();

  static JazlaParcelDefaults update(
    final JazlaParcelDefaults? current,
    final BulkEditableField field,
    final Object? value,
  ) {
    final JazlaParcelDefaults base = current ?? const JazlaParcelDefaults();
    return switch (field) {
      BulkEditableField.cropType => base.copyWith(cropType: value as String?),
      BulkEditableField.growthStages =>
        base.copyWith(growthStages: value as String?),
      BulkEditableField.usageType => base.copyWith(usageType: value as String?),
      BulkEditableField.notes => base.copyWith(notes: value as String?),
      BulkEditableField.isInheritance =>
        base.copyWith(isInheritance: value as bool),
      // These fields are not exposed by the Jazla bulk sheet today. Keeping
      // them explicit makes the policy exhaustive if the picker expands.
      BulkEditableField.creditType || BulkEditableField.reformType => base,
    };
  }

  static Parcel apply(
    final Parcel parcel,
    final JazlaParcelDefaults? defaults,
  ) {
    if (defaults == null || defaults.isEmpty) return parcel;

    Parcel updated = parcel;
    if (defaults.usageType != null) {
      updated = UsageTypeNotesSync.applyUsageTypeChange(
        updated,
        defaults.usageType!,
      );
    }
    if (defaults.isInheritance != null) {
      updated = updated.copyWith(isInheritance: defaults.isInheritance);
    }
    if (defaults.notes != null &&
        !updated.notes.contains(defaults.notes!.trim())) {
      updated = ParcelNotesSync.applyChangedNotes(
        updated,
        <String>[...updated.notes, defaults.notes!.trim()],
      );
    }

    // Notes can intentionally switch usage to مباني/بور. Only seed crop and
    // growth after that policy has run, and only while the final usage remains
    // agricultural.
    if (UsageType.fromLabel(updated.usageType) == UsageType.agricultural) {
      if (defaults.cropType != null) {
        updated = updated.copyWith(cropType: defaults.cropType);
      }
      if (defaults.growthStages != null) {
        updated = updated.copyWith(growthStages: defaults.growthStages);
      }
    }
    return updated;
  }
}
