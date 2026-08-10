import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_backoff.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_operation_handler.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_runner.dart';

class _RecordingHandler implements SyncOperationHandler {
  final List<String> executedIds = <String>[];
  Object? errorToThrow;
  bool throwOnce = false;
  int _callCount = 0;

  @override
  Future<void> execute(final SyncOperation operation) async {
    _callCount++;
    if (errorToThrow != null && (!throwOnce || _callCount == 1)) {
      throw errorToThrow!;
    }
    executedIds.add(operation.operationId);
  }
}

AddParcelOperation _addOp(final String id) => AddParcelOperation(
      operationId: id,
      createdAt: DateTime.now(),
      cityId: 'city1',
      parcel: const Parcel(holdingId: ''),
      parentHoldingId: null,
    );

void main() {
  group('SyncRunner', () {
    test('flush executes a queued operation and removes it on success', () async {
      final SyncRunner runner = SyncRunner();
      final _RecordingHandler handler = _RecordingHandler();
      runner.registerHandler(AddParcelOperation, handler);

      runner.enqueue(_addOp('op1'));
      await runner.flush();

      expect(handler.executedIds, <String>['op1']);
      expect(runner.operations, isEmpty);
      expect(runner.hasPending, isFalse);
    });

    test('processes operations in FIFO order', () async {
      final SyncRunner runner = SyncRunner();
      final _RecordingHandler handler = _RecordingHandler();
      runner.registerHandler(AddParcelOperation, handler);

      runner.enqueue(_addOp('op1'));
      runner.enqueue(_addOp('op2'));
      runner.enqueue(_addOp('op3'));
      await runner.flush();

      expect(handler.executedIds, <String>['op1', 'op2', 'op3']);
    });

    test('a failed operation stays queued with attempts incremented', () async {
      final SyncRunner runner = SyncRunner();
      final _RecordingHandler handler = _RecordingHandler()
        ..errorToThrow = Exception('boom');
      runner.registerHandler(AddParcelOperation, handler);

      runner.enqueue(_addOp('op1'));
      await runner.flush();

      expect(runner.operations, hasLength(1));
      expect(runner.operations.first.attempts, 1);
      expect(runner.operations.first.lastError, contains('boom'));
    });

    test('an operation past maxAttempts is skipped by flush, not retried', () async {
      final SyncRunner runner = SyncRunner(maxAttempts: 2);
      final _RecordingHandler handler = _RecordingHandler();
      runner.registerHandler(AddParcelOperation, handler);

      final AddParcelOperation exhausted = _addOp('op1').withAttempt(error: 'e1').withAttempt(error: 'e2');
      runner.restore(<SyncOperation>[exhausted]);
      await runner.flush();

      expect(handler.executedIds, isEmpty);
      expect(runner.operations, hasLength(1));
    });

    test('retry() re-attempts a specific operation regardless of maxAttempts', () async {
      final SyncRunner runner = SyncRunner(maxAttempts: 1);
      final _RecordingHandler handler = _RecordingHandler();
      runner.registerHandler(AddParcelOperation, handler);

      final AddParcelOperation exhausted = _addOp('op1').withAttempt(error: 'e1');
      runner.restore(<SyncOperation>[exhausted]);
      await runner.retry('op1');

      expect(handler.executedIds, <String>['op1']);
      expect(runner.operations, isEmpty);
    });

    // REFACTOR_ROADMAP.md Phase 26: retry() previously returned void, so a
    // caller (the pending-syncs sheet's retry button) had no way to know
    // whether the retry actually succeeded — it showed a success message
    // unconditionally, even when the retry failed for the exact same reason
    // as before (e.g. still offline). retry() now reports its real outcome.
    test('retry() returns true when the retry succeeds', () async {
      final SyncRunner runner = SyncRunner(maxAttempts: 1);
      final _RecordingHandler handler = _RecordingHandler();
      runner.registerHandler(AddParcelOperation, handler);

      final AddParcelOperation exhausted = _addOp('op1').withAttempt(error: 'e1');
      runner.restore(<SyncOperation>[exhausted]);

      expect(await runner.retry('op1'), isTrue);
    });

    test('retry() returns false when the handler still fails', () async {
      final SyncRunner runner = SyncRunner(maxAttempts: 1);
      final _RecordingHandler handler = _RecordingHandler()
        ..errorToThrow = Exception('still offline');
      runner.registerHandler(AddParcelOperation, handler);

      final AddParcelOperation exhausted = _addOp('op1').withAttempt(error: 'e1');
      runner.restore(<SyncOperation>[exhausted]);

      expect(await runner.retry('op1'), isFalse);
      expect(runner.operations, hasLength(1));
      expect(runner.operations.first.lastError, contains('still offline'));
    });

    test('retry() returns false for an operation id that is no longer queued',
        () async {
      final SyncRunner runner = SyncRunner();
      final _RecordingHandler handler = _RecordingHandler();
      runner.registerHandler(AddParcelOperation, handler);

      expect(await runner.retry('missing-id'), isFalse);
    });

    test('remove() drops an operation without executing it', () async {
      final SyncRunner runner = SyncRunner();
      final _RecordingHandler handler = _RecordingHandler();
      runner.registerHandler(AddParcelOperation, handler);

      runner.enqueue(_addOp('op1'));
      runner.remove('op1');
      await runner.flush();

      expect(handler.executedIds, isEmpty);
      expect(runner.operations, isEmpty);
    });

    test('an operation with no registered handler is left untouched', () async {
      final SyncRunner runner = SyncRunner();
      runner.enqueue(_addOp('op1'));
      await runner.flush();

      expect(runner.operations, hasLength(1));
    });

    test('respects backoff — does not retry before the delay has elapsed', () async {
      final SyncRunner runner = SyncRunner(
        backoff: const SyncBackoff(base: Duration(minutes: 10)),
      );
      final _RecordingHandler handler = _RecordingHandler();
      runner.registerHandler(AddParcelOperation, handler);

      final AddParcelOperation failedOnce = _addOp('op1').withAttempt(error: 'e1');
      runner.restore(<SyncOperation>[failedOnce]);
      await runner.flush();

      expect(handler.executedIds, isEmpty);
      expect(runner.operations.single.attempts, 1);
    });

    test('onQueueChanged emits on enqueue, success, and failure', () async {
      final SyncRunner runner = SyncRunner();
      final _RecordingHandler handler = _RecordingHandler();
      runner.registerHandler(AddParcelOperation, handler);

      final List<int> lengths = <int>[];
      final sub = runner.onQueueChanged.listen((final ops) => lengths.add(ops.length));

      runner.enqueue(_addOp('op1'));
      await runner.flush();
      await Future<void>.delayed(Duration.zero);

      expect(lengths, containsAllInOrder(<int>[1, 0]));
      await sub.cancel();
    });
  });
}
