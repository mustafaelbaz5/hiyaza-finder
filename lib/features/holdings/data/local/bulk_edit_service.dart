import '../model/bulk_editable_field.dart';
import '../model/parcel.dart';


/// Result of a [BulkEditService.apply] call: the updated parcel list plus
/// how many parcels were actually changed, for user feedback.
class BulkEditResult {
  const BulkEditResult({required this.parcels, required this.changedCount});

  final List<Parcel> parcels;
  final int changedCount;
}

/// Pure logic for applying one field's value across many parcels at once
/// (optionally scoped to one حوض). Extracted from `HoldingsRepository` so
/// the "which field maps to which copyWith call" switch lives in one
/// testable place instead of inline inside a stateful repository method.
class BulkEditService {
  const BulkEditService();

  /// [basin] and [parcelIds] are independent scope filters — when both are
  /// given, a parcel must satisfy both (basin match AND id in the set).
  /// [parcelIds] is what lets a Jazla's "تطبيق جماعي" apply only to its own
  /// parcels through this exact same logic, rather than a second bulk-edit
  /// implementation.
  BulkEditResult apply(
    final List<Parcel> parcels, {
    required final BulkEditableField field,
    required final Object? value,
    final String? basin,
    final Set<String>? parcelIds,
  }) {
    int changed = 0;
    final List<Parcel> updated = <Parcel>[];
    for (final Parcel p in parcels) {
      final bool inScope = (basin == null || p.basinName == basin) &&
          (parcelIds == null || parcelIds.contains(p.id));
      if (!inScope) {
        updated.add(p);
        continue;
      }
      updated.add(_applyField(p, field, value));
      changed++;
    }
    return BulkEditResult(parcels: updated, changedCount: changed);
  }

  Parcel _applyField(
    final Parcel p,
    final BulkEditableField field,
    final Object? value,
  ) =>
      switch (field) {
        BulkEditableField.cropType => p.copyWith(cropType: value as String?),
        BulkEditableField.notes => p.copyWith(
            notes: value == null ? const <String>[] : <String>[value as String],
          ),
        BulkEditableField.creditType => p.copyWith(creditType: value as String),
        BulkEditableField.reformType => p.copyWith(reformType: value as String),
        BulkEditableField.usageType => p.copyWith(usageType: value as String),
        BulkEditableField.isInheritance =>
          p.copyWith(isInheritance: value as bool),
        BulkEditableField.growthStages =>
          p.copyWith(growthStages: value as String),
      };
}
