import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/parcel_review/data/model/bulk_edit_outcome.dart';
import 'package:hiyaza_finder/features/parcel_review/data/model/bulk_editable_field.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/holdings_writer.dart';
import 'package:hiyaza_finder/features/parcel_editor/logic/cubit/parcel_editor_cubit.dart';
import 'package:hiyaza_finder/features/parcel_editor/logic/cubit/parcel_editor_state.dart';

class _RecordingWriter implements ParcelCatalogWriter {
  Parcel? savedParcel;
  Object? error;

  @override
  Future<void> updateParcel(final Parcel edited) async {
    if (error != null) throw error!;
    savedParcel = edited;
  }

  @override
  Future<BulkEditOutcome> bulkApplyField({
    required final BulkEditableField field,
    required final Object? value,
    final String? basin,
    final Set<String>? parcelIds,
    final void Function(double progress)? onProgress,
  }) =>
      throw UnimplementedError();

  @override
  Future<Parcel?> regenerateLocalParcelId(final String parcelId) =>
      throw UnimplementedError();

  @override
  Future<void> resetParcel(final String id) => throw UnimplementedError();
}

void main() {
  test(
    'switching to buildings clears crop fields before the local write',
    () async {
      final _RecordingWriter writer = _RecordingWriter();
      final ParcelEditorCubit cubit = ParcelEditorCubit(writer);
      const Parcel original = Parcel(
        id: 'parcel-1',
        holdingId: '101',
        usageType: 'زراعة',
        cropType: 'قمح',
        growthStages: 'مرحلة النمو الخضري',
      );

      await cubit.changeUsage(original, 'مباني');

      expect(writer.savedParcel?.usageType, 'مباني');
      expect(writer.savedParcel?.cropType, isNull);
      expect(writer.savedParcel?.growthStages, isNull);
      expect(writer.savedParcel?.notes, contains('الأرض بها مباني'));
      expect(cubit.state.status, ParcelEditorStatus.saved);
      await cubit.close();
    },
  );

  test('failed local write exposes failure without reporting a saved edit',
      () async {
    final _RecordingWriter writer = _RecordingWriter()
      ..error = StateError('write failed');
    final ParcelEditorCubit cubit = ParcelEditorCubit(writer);

    await cubit.changeCropType(
      const Parcel(id: 'parcel-2', holdingId: '102'),
      'ذرة',
    );

    expect(cubit.state.status, ParcelEditorStatus.failure);
    expect(cubit.state.parcel?.cropType, 'ذرة');
    expect(writer.savedParcel, isNull);
    await cubit.close();
  });
}
