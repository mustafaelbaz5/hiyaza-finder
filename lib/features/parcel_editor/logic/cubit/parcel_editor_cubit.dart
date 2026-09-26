import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:hiyaza_finder/features/parcel_editor/data/local/usage_type_notes_sync.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/holdings_writer.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'parcel_editor_state.dart';

/// Coordinates one parcel edit. UI supplies an intent; this Cubit applies
/// pure business policies and persists through the narrow writer contract.
class ParcelEditorCubit extends Cubit<ParcelEditorState> {
  ParcelEditorCubit(this._writer) : super(const ParcelEditorState());

  final ParcelCatalogWriter _writer;

  Future<void> changeUsage(final Parcel parcel, final String usageType) =>
      _save(UsageTypeNotesSync.applyUsageTypeChange(parcel, usageType));

  Future<void> changeCropType(final Parcel parcel, final String? cropType) =>
      _save(parcel.copyWith(cropType: cropType));

  Future<void> save(final Parcel parcel) => _save(parcel);

  Future<void> _save(final Parcel parcel) async {
    emit(ParcelEditorState(status: ParcelEditorStatus.saving, parcel: parcel));
    try {
      await _writer.updateParcel(parcel);
      emit(ParcelEditorState(status: ParcelEditorStatus.saved, parcel: parcel));
    } catch (error) {
      emit(ParcelEditorState(
        status: ParcelEditorStatus.failure,
        parcel: parcel,
        error: error,
      ));
    }
  }
}
