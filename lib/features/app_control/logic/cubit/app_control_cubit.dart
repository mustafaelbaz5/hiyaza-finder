import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../../../core/networking/network_info.dart';
import '../../data/model/app_control.dart';
import '../../data/repo/app_control_repository.dart';

class AppControlCubit extends Cubit<AppControl> with WidgetsBindingObserver {
  AppControlCubit(this._repository, this._networkInfo)
      : super(AppControl.open) {
    WidgetsBinding.instance.addObserver(this);
    _connectionSubscription =
        _networkInfo.onStatusChange.listen(_onConnectionChanged);
  }

  final AppControlRepository _repository;
  final NetworkInfo _networkInfo;
  late final StreamSubscription<InternetConnectionStatus>
      _connectionSubscription;

  Future<void> initialize() async {
    final AppControl? cached = await _repository.readCached();
    if (cached != null) emit(cached);
    await refresh();
  }

  Future<void> _onConnectionChanged(
      final InternetConnectionStatus status) async {
    if (status == InternetConnectionStatus.connected) await refresh();
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
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription.cancel();
    return super.close();
  }
}
