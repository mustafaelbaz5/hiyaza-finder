import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/model/jazla.dart';
import '../../data/local/jazla_preferences.dart';
import '../../data/repo/jazla_repo.dart';
import 'jazla_list_state.dart';

class JazlaListCubit extends Cubit<JazlaListState> {
  JazlaListCubit(this._repo, this.cityId, {final JazlaPreferences? preferences})
      : _preferences = preferences ?? const JazlaPreferences(),
        super(JazlaListState.initial());

  final JazlaRepo _repo;
  final String cityId;
  final JazlaPreferences _preferences;

  Future<void> load() async {
    emit(state.copyWith(status: JazlaListStatus.loading));
    try {
      final JazlaSort sort = await _preferences.loadSort(cityId);
      final List<Jazla> jazlas = await _repo.getAll(cityId);
      emit(state.copyWith(status: JazlaListStatus.loaded, jazlas: _sort(jazlas, sort), sort: sort));
    } on AppException catch (e) {
      emit(state.copyWith(status: JazlaListStatus.error, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(status: JazlaListStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> setSort(final JazlaSort sort) async {
    await _preferences.saveSort(cityId, sort);
    emit(state.copyWith(jazlas: _sort(state.jazlas, sort), sort: sort));
  }

  List<Jazla> _sort(final List<Jazla> values, final JazlaSort sort) {
    final List<Jazla> result = List<Jazla>.of(values);
    result.sort((final Jazla a, final Jazla b) => switch (sort) {
          JazlaSort.newest => b.createdAt.compareTo(a.createdAt),
          JazlaSort.updated => b.updatedAt.compareTo(a.updatedAt),
          JazlaSort.name => a.name.compareTo(b.name),
          JazlaSort.parcelCount => b.parcelCount.compareTo(a.parcelCount),
        });
    return result;
  }

  Future<void> createJazla(
    final String name, {
    final String? basinName,
    final double? targetFeddan,
    final double? targetQirat,
    final double? targetSahm,
    final double? targetAreaSqm,
  }) async {
    if (name.trim().isEmpty) return;
    try {
      await _repo.create(
        name.trim(),
        cityId,
        basinName: basinName,
        targetFeddan: targetFeddan,
        targetQirat: targetQirat,
        targetSahm: targetSahm,
        targetAreaSqm: targetAreaSqm,
      );
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(status: JazlaListStatus.error, errorMessage: e.message));
    }
  }

  Future<void> renameJazla(final String jazlaId, final String newName) async {
    if (newName.trim().isEmpty) return;
    try {
      await _repo.rename(jazlaId, newName.trim(), cityId);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(status: JazlaListStatus.error, errorMessage: e.message));
    }
  }

  Future<void> deleteJazla(final String jazlaId) async {
    try {
      await _repo.delete(jazlaId, cityId);
      await load();
    } on AppException catch (e) {
      emit(state.copyWith(status: JazlaListStatus.error, errorMessage: e.message));
    }
  }
}
