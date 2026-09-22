import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/model/app_control.dart';
import '../../data/repo/app_control_repository.dart';

class AppControlCubit extends Cubit<AppControl> with WidgetsBindingObserver {
  AppControlCubit(this._repository) : super(AppControl.open) {
    WidgetsBinding.instance.addObserver(this);
  }

  final AppControlRepository _repository;

  Future<void> initialize() async {
    final AppControl? cached = await _repository.readCached();
    if (cached != null) emit(cached);
    await refresh();
  }

  Future<void> refresh() async {
    try {
      emit(await _repository.refresh());
    } catch (_) {
      // Keep the last known state when the network is unavailable.
    }
  }

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }
}
