import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
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

  testWidgets('a retry that still fails shows the accurate failure message,'
      ' not a false success', (final tester) async {
    handler.shouldSucceed = false;
    await pumpSheet(tester);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('تعذّرت إعادة المحاولة — تحقق من اتصالك بالإنترنت'), findsOneWidget);
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

}
