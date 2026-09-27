import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_catalog/data/repo/holdings_reader.dart';
import '../../../parcel_catalog/data/repo/holdings_writer.dart';
import '../../../parcel_catalog/data/repo/parcel_detail_actions.dart';
import 'jazla_review_state.dart';

/// Session state for reviewing Jazla parcels. The screen stays declarative;
/// catalog writes and review actions remain behind narrow public contracts.
class JazlaReviewCubit extends Cubit<JazlaReviewState> {
  JazlaReviewCubit(
    this._writer,
    this._actions,
    this._reader, {
    required final List<Parcel> parcels,
    required final int initialIndex,
  }) : super(
          JazlaReviewState(
            parcels: List<Parcel>.unmodifiable(parcels),
            index: initialIndex < 0
                ? 0
                : initialIndex >= parcels.length
                    ? parcels.length - 1
                    : initialIndex,
          ),
        );

  final ParcelCatalogWriter _writer;
  final ParcelDetailActions _actions;
  final ParcelCatalogReader _reader;

  List<String> get availableBasins => _reader.availableBasins;
  List<Parcel> parcelsForHolding(final String holdingId) =>
      _reader.parcelsForHolding(holdingId);

  void previous() {
    if (state.canGoPrevious) emit(state.copyWith(index: state.index - 1));
  }

  void next() {
    if (state.canGoNext) emit(state.copyWith(index: state.index + 1));
  }

  Future<void> save(final Parcel updated) async {
    emit(state.copyWith(isSaving: true));
    try {
      await _writer.updateParcel(updated);
      _replace(updated);
    } finally {
      if (!isClosed) emit(state.copyWith(isSaving: false));
    }
  }

  void reflectCompletion(final Parcel updated) => _replace(updated);

  Future<Parcel?> setCompleted(
    final String parcelId, {
    required final bool completed,
  }) async {
    final Parcel? updated = await _actions.setParcelCompleted(
      parcelId,
      completed: completed,
    );
    if (updated != null) _replace(updated);
    return updated;
  }

  Future<void> reopen() async {
    final Parcel? updated = await _actions.setParcelCompleted(
      state.parcel.id,
      completed: false,
    );
    if (updated != null) _replace(updated);
  }

  Future<void> regenerate(final String parcelId) async {
    final Parcel? updated = await _actions.regenerateLocalParcelId(parcelId);
    if (updated != null) _replace(updated);
  }

  void _replace(final Parcel updated) {
    final List<Parcel> parcels = List<Parcel>.of(state.parcels);
    parcels[state.index] = updated;
    emit(state.copyWith(parcels: List<Parcel>.unmodifiable(parcels)));
  }
}
