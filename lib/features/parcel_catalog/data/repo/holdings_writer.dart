import 'package:hiyaza_finder/features/parcel_review/data/model/bulk_edit_outcome.dart';
import 'package:hiyaza_finder/features/parcel_review/data/model/bulk_editable_field.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

/// Write-side contract for holdings data, kept separate from
/// [ParcelCatalogReader] (interface segregation) — screens that only edit
/// shouldn't need to depend on search/query methods they never call.
abstract class ParcelCatalogWriter {
  Future<void> updateParcel(final Parcel edited);

  Future<void> resetParcel(final String id);

  Future<Parcel?> regenerateLocalParcelId(final String parcelId);

  Future<BulkEditOutcome> bulkApplyField({
    required final BulkEditableField field,
    required final Object? value,
    final String? basin,
    final Set<String>? parcelIds,
    final void Function(double progress)? onProgress,
  });
}
