import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/model/app_control.dart';
import '../../data/repo/app_control_repository.dart';

class AppControlCubit extends Cubit<AppControl> {
  AppControlCubit(this._repository) : super(AppControl.open);

  final AppControlRepository _repository;

  Future<void> initialize() async {
    final AppControl? cached = await _repository.readCached();
    if (cached != null) emit(cached);
    try {
      emit(await _repository.refresh());
    } catch (_) {
      // Offline startup uses the cached value or the safe open default.
    }
  }

  Future<void> refresh() async {
    try {
      emit(await _repository.refresh());
    } catch (_) {
      // Keep the last known state when the network is unavailable.
    }
  }
}
