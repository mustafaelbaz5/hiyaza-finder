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

  /// [_queue.pendingCountChanges] can fire (e.g. mid-[retryFailed], from
  /// one of its several `update()` calls) after this cubit has already
  /// been closed — the listener registration itself is cancelled in
  /// [close], but an in-flight `await` here can still resolve afterwards.
  /// Every `emit` in this class is guarded by [isClosed] for that reason.
  Future<void> _refresh() async {
    final List<SyncOperation> ops = await _queue.pending();
    if (isClosed) return;
    final int failed = ops.where((final SyncOperation o) => o.attempts >= syncMaxAttempts).length;
    emit(state.copyWith(pendingCount: ops.length, failedCount: failed));
  }

  /// The manual "مزامنة الآن" action, the connectivity-regained trigger,
  /// and the app-resume trigger all funnel through here.
  Future<void> flushNow() async {
    if (state.isSyncing) return;
    emit(state.copyWith(isSyncing: true));
    await _runner.flush();
    await _refresh();
    if (isClosed) return;
    emit(state.copyWith(isSyncing: false));
  }

  /// The full queue contents — what the sync details sheet lists, since
  /// [state] only tracks aggregate counts.
  Future<List<SyncOperation>> pendingOperations() => _queue.pending();

  /// Discards a single queued operation without pushing it — the sync
  /// sheet's escape hatch for an operation that can never succeed (e.g.
  /// one enqueued with a payload shape a since-fixed bug produced; fixing
  /// the bug only prevents *new* operations from having the problem, it
  /// can't repair one already serialized to the local outbox).
  Future<void> discardOperation(final String operationId) async {
    await _queue.remove(operationId);
    await _refresh();
  }

  /// Clears every permanently-failed operation's attempt count and
  /// immediately retries — the sync badge's action when tapped in the
  /// "failed" state, since [flushNow] alone would just skip them again.
  Future<void> retryFailed() async {
    if (state.isSyncing) return;
    final List<SyncOperation> ops = await _queue.pending();
    for (final SyncOperation op in ops) {
      if (op.attempts >= syncMaxAttempts) {
        await _queue.update(op.resetAttempts());
      }
    }
    await flushNow();
  }

  @override
  Future<void> close() {
    _countSub.cancel();
    _connectivitySub.cancel();
    return super.close();
  }
}
