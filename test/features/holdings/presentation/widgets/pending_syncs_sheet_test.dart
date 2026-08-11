import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/pending_syncs_sheet.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_operation_handler.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_runner.dart';

import '../../../../support/localized_widget_test_harness.dart';

/// `REFACTOR_ROADMAP.md` Phase 26: the retry button used to call
/// `SyncRunner.retry` and then unconditionally show a success snackbar,
/// even when the retry failed (e.g. still offline) — the tile kept showing
/// the exact same error with no accurate feedback. Verifies the button now
/// shows a loading state while retrying and an accurate result afterward.
class _ControllableHandler implements SyncOperationHandler {
  bool shouldSucceed = false;

  @override
  Future<void> execute(final SyncOperation operation) async {
    if (!shouldSucceed) throw Exception('still offline');
  }
}

AddParcelOperation _failedOp() => AddParcelOperation(
      operationId: 'op1',
      createdAt: DateTime.now(),
      cityId: 'city1',
      parcel: const Parcel(holdingId: '', holderName: 'Ahmed'),
      parentHoldingId: null,
    ).withAttempt(error: 'network error');

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  late SyncRunner runner;
  late _ControllableHandler handler;

  setUp(() async {
    await getIt.reset();
    handler = _ControllableHandler();
    runner = SyncRunner()..registerHandler(AddParcelOperation, handler);
    runner.restore(<SyncOperation>[_failedOp()]);
    getIt.registerSingleton<SyncRunner>(runner);
    getIt.registerLazySingleton<HoldingsRepository>(HoldingsRepository.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpSheet(final WidgetTester tester) async {
    await pumpLocalized(
      tester,
      Builder(
        builder: (final BuildContext context) => ElevatedButton(
          onPressed: () => showPendingSyncsSheet(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a retry that still fails shows the real failure reason, not '
      'a hardcoded connectivity message', (final tester) async {
    handler.shouldSucceed = false;
    await pumpSheet(tester);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // `_ControllableHandler.execute` throws `Exception('still offline')` —
    // its `toString()` is what SyncRunner captures as `lastError`, and that
    // real reason must be what the user sees, not a hardcoded generic
    // "check your internet connection" regardless of what actually failed.
    expect(find.textContaining('still offline'), findsWidgets);
    expect(find.text('تمت المزامنة بنجاح'), findsNothing);
    // The operation must still be visible in the queue — the retry did not
    // silently drop it despite failing.
    expect(runner.operations, hasLength(1));
  });

  testWidgets('a retry that succeeds shows the real success message',
      (final tester) async {
    handler.shouldSucceed = true;
    await pumpSheet(tester);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('تمت المزامنة بنجاح'), findsOneWidget);
    expect(runner.operations, isEmpty);
  });

  testWidgets('the tile shows a detail line with the queued-at time',
      (final tester) async {
    handler.shouldSucceed = false;
    await pumpSheet(tester);

    expect(find.textContaining('أُضيف في'), findsOneWidget);
    expect(find.textContaining('1 محاولة'), findsOneWidget);
  });

  group('CompleteParcelOperation retry — already-synced messaging', () {
    late SyncRunner completeRunner;
    late _ControllableHandler completeHandler;

    CompleteParcelOperation failedCompleteOp() => CompleteParcelOperation(
          operationId: 'op-complete',
          createdAt: DateTime.now(),
          parcelId: 'p1',
          isFieldAdded: false,
          completed: true,
          completedAt: DateTime.now(),
          completedByUserId: 'user-1',
        ).withAttempt(error: 'conflict');

    setUp(() async {
      await getIt.reset();
      completeHandler = _ControllableHandler();
      completeRunner = SyncRunner()
        ..registerHandler(CompleteParcelOperation, completeHandler);
      completeRunner.restore(<SyncOperation>[failedCompleteOp()]);
      getIt.registerSingleton<SyncRunner>(completeRunner);
      getIt.registerLazySingleton<HoldingsRepository>(HoldingsRepository.new);
    });

    testWidgets(
        'a successful retry after a prior failure shows the '
        '"already synced" message instead of the generic success one — '
        'this is the case where CompleteParcelSyncHandler quietly found '
        'the server already matched and skipped the write', (final tester) async {
      completeHandler.shouldSucceed = true;
      await pumpSheet(tester);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('تم رفع هذا التغيير بالفعل — تمت إزالته من قائمة الانتظار'),
        findsOneWidget,
      );
      expect(find.text('تمت المزامنة بنجاح'), findsNothing);
    });
  });
}
