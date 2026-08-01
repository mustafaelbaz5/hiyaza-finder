import 'package:flutter/foundation.dart';

import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/entities/sync_operation.dart';
import '../domain/repositories/sync_api.dart';
import '../domain/repositories/sync_queue.dart';
import '../domain/services/sync_backoff.dart';

/// An operation is parked as permanently failed after this many attempts
/// — surfaced in the UI instead of retried forever or silently dropped.
const int syncMaxAttempts = 5;

/// Drains the outbox: pushes each eligible pending operation, removing it
/// on success and bumping its attempt count (with backoff) on failure.
/// Sequential and in order — never runs two flushes concurrently.
class SyncRunner {
  SyncRunner({
    required final SyncQueue queue,
    required final SyncApi api,
    required final AuthRepository authRepository,
  })  : _queue = queue,
        _api = api,
        _authRepository = authRepository;

  final SyncQueue _queue;
  final SyncApi _api;
  final AuthRepository _authRepository;

  bool _isFlushing = false;

  Future<void> flush() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final String? userId = _authRepository.currentUser?.id;
      if (userId == null) {
        debugPrint('[SyncRunner] flush skipped — no signed-in user');
        return; // signed out — nothing to sync as whom
      }

      final List<SyncOperation> ops = await _queue.pending();
      final DateTime now = DateTime.now();

      for (final SyncOperation op in ops) {
        if (op.attempts >= syncMaxAttempts) continue; // parked as failed
        if (!SyncBackoff.isEligible(op.attempts, op.lastAttemptAt, now)) {
          continue;
        }

        try {
          await _push(op, userId);
          await _queue.remove(op.id);
        } catch (e) {
          debugPrint('[SyncRunner] push failed for ${op.runtimeType} (${op.id}): $e');
          await _queue.update(
            op.withIncrementedAttempts(DateTime.now(), error: e.toString()),
          );
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _push(final SyncOperation op, final String userId) => switch (op) {
        final EditHoldingOperation o => _api.pushEditHolding(o, editedByUserId: userId),
        final BulkEditOperation o => _api.pushBulkEdit(o, editedByUserId: userId),
        final AddRecordOperation o => _api.pushAddRecord(o, createdByUserId: userId),
      };
}
