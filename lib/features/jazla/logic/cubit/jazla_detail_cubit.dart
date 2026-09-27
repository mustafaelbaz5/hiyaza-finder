import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_catalog/data/repo/holdings_reader.dart';
import '../../../parcel_catalog/data/repo/holdings_writer.dart';
import '../../../parcel_review/data/model/bulk_edit_outcome.dart';
import '../../../parcel_review/data/model/bulk_editable_field.dart';
import '../../data/local/jazla_parcel_defaults_policy.dart';
import '../../data/model/jazla.dart';
import '../../data/model/jazla_parcel_defaults.dart';
import '../../data/repo/jazla_repo.dart';
import 'jazla_detail_state.dart';

class JazlaDetailCubit extends Cubit<JazlaDetailState> {
  JazlaDetailCubit(this._repo, this._holdingsReader, this.jazlaId, this.cityId,
      [this._writer])
      : super(JazlaDetailState.initial());

  final JazlaRepo _repo;
  final ParcelCatalogReader _holdingsReader;
  final ParcelCatalogWriter? _writer;
  final String jazlaId;
  final String cityId;

  /// Resolves `jazla.parcelIds` (this Jazla's only real data) to live
  /// [Parcel] objects via [ParcelCatalogReader] — never cached inside the Jazla
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
      if (isClosed) return;
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
          pendingParcelIds: const <String>{},
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(
          status: JazlaDetailStatus.error, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          status: JazlaDetailStatus.error, errorMessage: e.toString()));
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
      if (isClosed) return;
      emit(state.copyWith(
          status: JazlaDetailStatus.error, errorMessage: e.message));
    }
  }

  /// The detail Cubit is the only owner of a Jazla's visible parcel list.
  /// Updating it optimistically keeps the counter, list, and area summary in
  /// sync while the local write is persisted; a failed write restores the
  /// exact previous snapshot.
  Future<bool> addParcel(final Parcel parcel) async {
    final Jazla? current = state.jazla;
    if (current == null || current.parcelIds.contains(parcel.id)) return false;

    final JazlaDetailState previous = state;
    final Jazla updated = current.copyWith(
      parcelIds: <String>[...current.parcelIds, parcel.id],
    );
    emit(
      state.copyWith(
        status: JazlaDetailStatus.loaded,
        jazla: updated,
        parcels: <Parcel>[...state.parcels, parcel],
        pendingParcelIds: <String>{...state.pendingParcelIds, parcel.id},
        errorMessage: null,
      ),
    );
    try {
      await _repo.addParcel(jazlaId, parcel.id, cityId);
      if (isClosed) return true;
      emit(
        state.copyWith(
          pendingParcelIds: <String>{...state.pendingParcelIds}
            ..remove(parcel.id),
        ),
      );
      return true;
    } on AppException catch (error) {
      if (isClosed) return false;
      emit(previous.copyWith(
        status: JazlaDetailStatus.loaded,
        errorMessage: error.message,
      ));
      return false;
    } catch (error) {
      if (isClosed) return false;
      emit(previous.copyWith(
        status: JazlaDetailStatus.loaded,
        errorMessage: error.toString(),
      ));
      return false;
    }
  }

  /// Re-resolves only the parcels already belonging to this Jazla. It is
  /// used after editing/reviewing a parcel, without reloading Jazla storage.
  void refreshVisibleParcels() {
    if (isClosed) return;
    final Jazla? current = state.jazla;
    if (current == null) return;
    emit(state.copyWith(parcels: _resolveParcels(current)));
  }

  Future<void> updateArea({
    final double? feddan,
    final double? qirat,
    final double? sahm,
    final double? squareMeters,
  }) async {
    final Jazla? current = state.jazla;
    if (current == null) return;
    final Jazla updated = Jazla(
      id: current.id,
      cityId: current.cityId,
      name: current.name,
      basinName: current.basinName,
      parcelIds: current.parcelIds,
      targetFeddan: feddan,
      targetQirat: qirat,
      targetSahm: sahm,
      targetAreaSqmOverride: squareMeters,
      parcelDefaults: current.parcelDefaults,
      createdAt: current.createdAt,
    );
    emit(state.copyWith(jazla: updated));
    try {
      await _repo.updateArea(
        jazlaId,
        cityId,
        targetFeddan: feddan,
        targetQirat: qirat,
        targetSahm: sahm,
        targetAreaSqm: squareMeters,
      );
    } on AppException catch (e) {
      await load();
      if (isClosed) return;
      emit(state.copyWith(
          status: JazlaDetailStatus.error, errorMessage: e.message));
    }
  }

  Future<BulkEditOutcome> applyBulkField({
    required final BulkEditableField field,
    required final Object? value,
    required final Set<String> parcelIds,
    final void Function(double progress)? onProgress,
  }) {
    final ParcelCatalogWriter? writer = _writer;
    if (writer == null) {
      throw StateError('ParcelCatalogWriter is required for bulk Jazla edits.');
    }
    return writer.bulkApplyField(
      field: field,
      value: value,
      parcelIds: parcelIds,
      onProgress: onProgress,
    );
  }

  Future<void> updateParcelDefault(
    final BulkEditableField field,
    final Object? value,
  ) async {
    final Jazla? current = state.jazla;
    if (current == null) return;
    final JazlaParcelDefaults defaults =
        JazlaParcelDefaultsPolicy.update(current.parcelDefaults, field, value);
    try {
      await _repo.updateParcelDefaults(jazlaId, cityId, defaults);
      if (isClosed) return;
      emit(state.copyWith(jazla: current.copyWith(parcelDefaults: defaults)));
    } on AppException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: e.message));
    }
  }

  Future<void> updateBasin(final String? basinName) async {
    final Jazla? current = state.jazla;
    if (current == null) return;
    emit(
      state.copyWith(
        jazla: Jazla(
          id: current.id,
          cityId: current.cityId,
          name: current.name,
          basinName: basinName,
          parcelIds: current.parcelIds,
          targetFeddan: current.targetFeddan,
          targetQirat: current.targetQirat,
          targetSahm: current.targetSahm,
          targetAreaSqmOverride: current.targetAreaSqmOverride,
          parcelDefaults: current.parcelDefaults,
          createdAt: current.createdAt,
        ),
      ),
    );
    try {
      await _repo.updateBasin(jazlaId, cityId, basinName);
    } on AppException catch (e) {
      await load();
      if (isClosed) return;
      emit(state.copyWith(
          status: JazlaDetailStatus.error, errorMessage: e.message));
    }
  }

  Future<void> renameJazla(final String name) async {
    final Jazla? current = state.jazla;
    if (current == null || name.trim().isEmpty) return;
    final Jazla updated = current.copyWith(name: name.trim());
    emit(state.copyWith(jazla: updated));
    try {
      await _repo.rename(jazlaId, name.trim(), cityId);
    } on AppException catch (e) {
      await load();
      if (isClosed) return;
      emit(state.copyWith(
          status: JazlaDetailStatus.error, errorMessage: e.message));
    }
  }

  Future<void> deleteJazla() async {
    try {
      await _repo.delete(jazlaId, cityId);
      if (isClosed) return;
      emit(state.copyWith(status: JazlaDetailStatus.notFound));
    } on AppException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
          status: JazlaDetailStatus.error, errorMessage: e.message));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
          status: JazlaDetailStatus.error, errorMessage: e.toString()));
    }
  }

  /// Removes a parcel from this Jazla only — the parcel itself is never
  /// touched, deleted, or otherwise mutated (`JazlaRepo` never sees a
  /// `Parcel`, only its id).
  Future<bool> removeParcel(final String parcelId) async {
    final Jazla? current = state.jazla;
    if (current == null || !current.parcelIds.contains(parcelId)) return false;
    final JazlaDetailState previous = state;
    final Jazla updated = current.copyWith(
      parcelIds: current.parcelIds.where((final id) => id != parcelId).toList(),
    );
    emit(
      state.copyWith(
        status: JazlaDetailStatus.loaded,
        jazla: updated,
        parcels: state.parcels.where((final p) => p.id != parcelId).toList(),
        pendingParcelIds: <String>{...state.pendingParcelIds, parcelId},
        errorMessage: null,
      ),
    );
    try {
      await _repo.removeParcel(jazlaId, parcelId, cityId);
      if (isClosed) return true;
      emit(
        state.copyWith(
          pendingParcelIds: <String>{...state.pendingParcelIds}
            ..remove(parcelId),
        ),
      );
      return true;
    } on AppException catch (error) {
      if (isClosed) return false;
      emit(previous.copyWith(
        status: JazlaDetailStatus.loaded,
        errorMessage: error.message,
      ));
      return false;
    } catch (error) {
      if (isClosed) return false;
      emit(previous.copyWith(
        status: JazlaDetailStatus.loaded,
        errorMessage: error.toString(),
      ));
      return false;
    }
  }
}
