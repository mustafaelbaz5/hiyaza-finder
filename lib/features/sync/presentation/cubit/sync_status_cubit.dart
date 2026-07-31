import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../../../core/networking/network_info.dart';
import '../../data/sync_runner.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/repositories/sync_queue.dart';
import 'sync_status_state.dart';

/// Drives the sync status badge: tracks how many operations are pending
/// (and how many are permanently failed), and triggers a flush on
/// connectivity regained (in addition to the app-resume and manual
/// triggers wired at the app/widget level).
class SyncStatusCubit extends Cubit<SyncStatusState> {
  SyncStatusCubit({
    required final SyncQueue queue,
    required final SyncRunner runner,
    required final NetworkInfo networkInfo,
  })  : _queue = queue,
        _runner = runner,
        super(const SyncStatusState()) {
    _countSub = _queue.pendingCountChanges.listen((final int _) => _refresh());
    _connectivitySub = networkInfo.onStatusChange.listen(
      (final InternetConnectionStatus status) {
        if (status == InternetConnectionStatus.connected) flushNow();
      },
    );
    _refresh();
  }

  final SyncQueue _queue;
  final SyncRunner _runner;
  late final StreamSubscription<int> _countSub;
  late final StreamSubscription<InternetConnectionStatus> _connectivitySub;

  Future<void> _refresh() async {
    final List<SyncOperation> ops = await _queue.pending();
    final int failed =
        ops.where((final SyncOperation o) => o.attempts >= syncMaxAttempts).length;
    emit(state.copyWith(pendingCount: ops.length, failedCount: failed));
  }

  /// The manual "مزامنة الآن" action, the connectivity-regained trigger,
  /// and the app-resume trigger all funnel through here.
  Future<void> flushNow() async {
    if (state.isSyncing) return;
    emit(state.copyWith(isSyncing: true));
    await _runner.flush();
    await _refresh();
    emit(state.copyWith(isSyncing: false));
  }

  @override
  Future<void> close() {
    _countSub.cancel();
    _connectivitySub.cancel();
    return super.close();
  }
}
