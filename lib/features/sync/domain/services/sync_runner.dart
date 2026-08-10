import 'dart:async';

import '../entities/sync_operation.dart';
import 'sync_backoff.dart';
import 'sync_operation_handler.dart';

/// Generic outbox engine — zero imports from any feature (`SYSTEM_DESIGN.md`
/// §5.1). Holds the pending-operations queue in memory (mirrored to durable
/// storage by whoever calls [enqueue]/[remove] — see
/// `HoldingsRepository`/`SyncQueueStore`), processes it sequentially in
/// FIFO order, and applies [SyncBackoff] between retries on a per-operation
/// failure. An operation that reaches [maxAttempts] is left in the queue
/// (still visible via [operations]) but is no longer auto-retried by
/// [flush] — [retry] can still be called on it explicitly (the "failed
/// syncs" UI's manual retry action).
///
/// Dispatch to the right [SyncOperationHandler] is by runtime type
/// (`operation.runtimeType`), registered once via [registerHandler] — this
/// keeps `SyncRunner` from needing to know about `AddParcelOperation` vs.
/// `EditParcelOperation` etc. by name, just that *some* handler exists for
/// whatever type it's holding.
class SyncRunner {
  SyncRunner({this.maxAttempts = 5, final SyncBackoff backoff = const SyncBackoff()})
      : _backoff = backoff;

  final int maxAttempts;
  final SyncBackoff _backoff;

  final Map<Type, SyncOperationHandler> _handlers = <Type, SyncOperationHandler>{};
  final List<SyncOperation> _queue = <SyncOperation>[];
  final StreamController<List<SyncOperation>> _controller =
      StreamController<List<SyncOperation>>.broadcast();

  /// Guards against two overlapping [flush] calls (e.g. a reconnect event
  /// firing while a manual flush from the pending-syncs sheet is already
  /// running) processing the same head-of-queue operation twice.
  bool _isFlushing = false;

  Stream<List<SyncOperation>> get onQueueChanged => _controller.stream;

  List<SyncOperation> get operations => List<SyncOperation>.unmodifiable(_queue);

  bool get hasPending => _queue.isNotEmpty;

  void registerHandler(final Type operationType, final SyncOperationHandler handler) {
    _handlers[operationType] = handler;
  }

  /// Restores a queue loaded from durable storage at app start — replaces
  /// whatever's currently held, since this is only ever called once before
  /// any [enqueue].
  void restore(final List<SyncOperation> operations) {
    _queue
      ..clear()
      ..addAll(operations);
    _notify();
  }

  void enqueue(final SyncOperation operation) {
    _queue.add(operation);
    _notify();
  }

  void _notify() => _controller.add(operations);

  /// Processes the queue front-to-back, awaiting each operation's handler in
  /// turn (not concurrently — two edits to the same holding must apply in
  /// the order the user made them, not whichever network call happens to
  /// return first). Stops attempting an operation once it's already at
  /// [maxAttempts] (skips it, moves to the next) rather than blocking the
  /// rest of the queue behind one permanently-failing item. Safe to call
  /// repeatedly (e.g. on every reconnect/app-resume) — a no-op if already
  /// flushing or the queue is empty.
  Future<void> flush() async {
    if (_isFlushing || _queue.isEmpty) return;
    _isFlushing = true;
    try {
      // Iterate over a snapshot of ids, not indices — a successful
      // operation is removed from `_queue` mid-loop, and a failed one may
      // be *replaced* (via `withAttempt`) at the same logical position but
      // not the same list index if an earlier item was already removed.
      final List<String> idsToProcess = <String>[
        for (final SyncOperation op in _queue)
          if (op.attempts < maxAttempts) op.operationId,
      ];

      for (final String id in idsToProcess) {
        final int idx = _queue.indexWhere((final SyncOperation o) => o.operationId == id);
        if (idx < 0) continue; // Already removed by a prior successful attempt.
        await _attempt(idx, respectBackoff: true);
      }
    } finally {
      _isFlushing = false;
    }
  }

  /// Re-attempts one specific operation regardless of [maxAttempts] or
  /// backoff timing — the failed-syncs UI's explicit "retry" action on a
  /// parked item. An explicit user tap should never be silently ignored
  /// because the backoff clock hasn't elapsed yet.
  ///
  /// Returns whether the retry actually succeeded — the pending-syncs sheet
  /// needs this to show an accurate result instead of a blanket "success"
  /// message regardless of outcome (a real bug: the operation staying stuck
  /// with the exact same `لا يوجد اتصال` error after a failed retry, while
  /// the UI claimed it worked).
  Future<bool> retry(final String operationId) async {
    final int idx = _queue.indexWhere((final SyncOperation o) => o.operationId == operationId);
    if (idx < 0) return false;
    return _attempt(idx, respectBackoff: false);
  }

  Future<bool> _attempt(final int idx, {required final bool respectBackoff}) async {
    final SyncOperation op = _queue[idx];
    final SyncOperationHandler? handler = _handlers[op.runtimeType];
    if (handler == null) return false;

    // A retry that's due for backoff is skipped this round rather than
    // forced — `flush()` may be called far more often than any individual
    // operation should actually be retried (every app resume, every
    // reconnect). Explicit manual retries ([retry]) bypass this check.
    if (respectBackoff && op.attempts > 0 && op.lastAttemptAt != null) {
      final Duration elapsed = DateTime.now().difference(op.lastAttemptAt!);
      if (elapsed < _backoff.delayFor(op.attempts)) return false;
    }

    try {
      await handler.execute(op);
      _queue.removeAt(idx);
      _notify();
      return true;
    } catch (error) {
      if (idx < _queue.length && _queue[idx].operationId == op.operationId) {
        _queue[idx] = op.withAttempt(error: error.toString());
        _notify();
      }
      return false;
    }
  }

  /// Drops a queued operation without executing it — the user discarding a
  /// permanently-failed item from the failed-syncs UI (e.g. it's no longer
  /// relevant, or they've made the same change another way).
  void remove(final String operationId) {
    _queue.removeWhere((final SyncOperation o) => o.operationId == operationId);
    _notify();
  }

  Future<void> dispose() => _controller.close();
}
