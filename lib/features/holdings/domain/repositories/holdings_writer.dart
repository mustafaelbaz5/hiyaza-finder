import '../entities/bulk_editable_field.dart';
import '../entities/parcel.dart';

/// Write-side contract for holdings data, kept separate from
/// [HoldingsReader] (interface segregation) — screens that only edit
/// shouldn't need to depend on search/query methods they never call.
abstract class HoldingsWriter {
  Future<void> updateParcel(final Parcel edited);

  Future<void> resetParcel(final String id);

  Future<int> bulkApplyField({
    required final BulkEditableField field,
    required final Object? value,
    final String? basin,
  });
}
