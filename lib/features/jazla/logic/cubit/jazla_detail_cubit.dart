import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../holdings/data/model/parcel.dart';
import '../../../holdings/data/repo/holdings_reader.dart';
import '../../data/model/jazla.dart';
import '../../data/repo/jazla_repo.dart';
import 'jazla_detail_state.dart';

class JazlaDetailCubit extends Cubit<JazlaDetailState> {
  JazlaDetailCubit(this._repo, this._holdingsReader, this.jazlaId, this.cityId)
      : super(JazlaDetailState.initial());

  final JazlaRepo _repo;
  final HoldingsReader _holdingsReader;
  final String jazlaId;
  final String cityId;

  /// Resolves `jazla.parcelIds` (this Jazla's only real data) to live
  /// [Parcel] objects via [HoldingsReader] — never cached inside the Jazla
  /// itself, always re-derived so the detail screen reflects the parcels'
  /// real, current field values.
  List<Parcel> _resolveParcels(final Jazla jazla) {
    final Map<String, Parcel> byId = <String, Parcel>{
      for (final Parcel p in _holdingsReader.parcels) p.id: p,
    };
    return jazla.parcelIds
        .map((final String id) => byId[id])
        .whereType<Parcel>()
        .toList();
  }

  Future<void> load() async {
    emit(state.copyWith(status: JazlaDetailStatus.loading));
    try {
      final List<Jazla> all = await _repo.getAll(cityId);
      Jazla? jazla;
      for (final Jazla j in all) {
        if (j.id == jazlaId) {
          jazla = j;
          break;
        }
      }
      if (jazla == null) {
        emit(state.copyWith(status: JazlaDetailStatus.notFound));
        return;
      }
      emit(
        state.copyWith(
          status: JazlaDetailStatus.loaded,
          jazla: jazla,
          parcels: _resolveParcels(jazla),
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(status: JazlaDetailStatus.error, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(status: JazlaDetailStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> reorder(final List<String> newOrderIds) async {
    final Jazla? jazla = state.jazla;
    if (jazla == null) return;
    // Optimistic local update — the detail screen already reflects the new
    // order while the write persists, matching a `ReorderableListView`'s
    // expected immediate feedback.
    final Jazla updated = jazla.copyWith(parcelIds: newOrderIds);
    emit(state.copyWith(jazla: updated, parcels: _resolveParcels(updated)));
    try {
      await _repo.reorderParcels(jazlaId, newOrderIds, cityId);
    } on AppException catch (e) {
      emit(state.copyWith(status: JazlaDetailStatus.error, errorMessage: e.message));
    }
  }

  /// Removes a parcel from this Jazla only — the parcel itself is never
  /// touched, deleted, or otherwise mutated (`JazlaRepo` never sees a
  /// `Parcel`, only its id).
  Future<void> removeParcel(final String parcelId) async {
    try {
      await _repo.removeParcel(jazlaId, parcelId, cityId);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(status: JazlaDetailStatus.error, errorMessage: e.message));
    }
  }
}
