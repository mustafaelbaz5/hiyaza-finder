import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/model/jazla.dart';
import '../../data/repo/jazla_repo.dart';
import 'jazla_list_state.dart';

class JazlaListCubit extends Cubit<JazlaListState> {
  JazlaListCubit(this._repo, this.cityId) : super(JazlaListState.initial());

  final JazlaRepo _repo;
  final String cityId;

  Future<void> load() async {
    emit(state.copyWith(status: JazlaListStatus.loading));
    try {
      final List<Jazla> jazlas = await _repo.getAll(cityId);
      emit(state.copyWith(status: JazlaListStatus.loaded, jazlas: jazlas));
    } on AppException catch (e) {
      emit(state.copyWith(status: JazlaListStatus.error, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(status: JazlaListStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> createJazla(final String name) async {
    if (name.trim().isEmpty) return;
    try {
      await _repo.create(name.trim(), cityId);
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
