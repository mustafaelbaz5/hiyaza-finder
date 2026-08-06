import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/sync_operation_summary.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';

import '../../../support/localized_widget_test_harness.dart';

/// `syncOperationSummary` calls `.tr()`, which silently falls back to the
/// raw translation key when no `EasyLocalization` has loaded translations
/// in this test process (`CLAUDE.md`'s localization section) — so this
/// pumps a throwaway widget that calls the function from inside a real,
/// loaded `EasyLocalization`/`MaterialApp` tree, then asserts against the
/// actual Arabic string from `assets/lang/ar.json`.
class _SummaryProbe extends StatelessWidget {
  const _SummaryProbe(this.operation);

  final SyncOperation operation;

  @override
  Widget build(final BuildContext context) => Text(syncOperationSummary(operation));
}

void main() {
  final DateTime now = DateTime(2026, 8, 6);

  testWidgets('AddParcelOperation with no parent shows "new person: name"',
      (final tester) async {
    await pumpLocalized(
      tester,
      _SummaryProbe(
        AddParcelOperation(
          operationId: 'op1',
          createdAt: now,
          cityId: 'city1',
          parcel: const Parcel(holdingId: '', holderName: 'محمد'),
          parentHoldingId: null,
        ),
      ),
    );

    expect(find.text('شخص جديد: محمد'), findsOneWidget);
  });

  testWidgets('AddParcelOperation with a parent shows "new parcel"',
      (final tester) async {
    await pumpLocalized(
      tester,
      _SummaryProbe(
        AddParcelOperation(
          operationId: 'op1',
          createdAt: now,
          cityId: 'city1',
          parcel: const Parcel(holdingId: '', holderName: 'محمد'),
          parentHoldingId: 'parent1',
        ),
      ),
    );

    expect(find.text('قطعة أرض جديدة'), findsOneWidget);
  });

  testWidgets('DeleteParcelOperation shows "delete record"', (final tester) async {
    await pumpLocalized(
      tester,
      _SummaryProbe(
        DeleteParcelOperation(
          operationId: 'op2',
          createdAt: now,
          addedHoldingId: 'ah1',
        ),
      ),
    );

    expect(find.text('حذف سجل'), findsOneWidget);
  });

  testWidgets('EditParcelOperation shows "holding edit"', (final tester) async {
    await pumpLocalized(
      tester,
      _SummaryProbe(
        EditParcelOperation(
          operationId: 'op3',
          createdAt: now,
          holdingId: 'h1',
          cityId: 'city1',
          payload: const <String, dynamic>{},
        ),
      ),
    );

    expect(find.text('تعديل بيانات حيازة'), findsOneWidget);
  });

  testWidgets('MarkReviewedOperation shows "reviewed status update"',
      (final tester) async {
    await pumpLocalized(
      tester,
      _SummaryProbe(
        MarkReviewedOperation(
          operationId: 'op4',
          createdAt: now,
          parcelId: 'p1',
          isFieldAdded: true,
          reviewed: true,
          reviewedAt: now,
          reviewedByUserId: 'user1',
        ),
      ),
    );

    expect(find.text('تحديث حالة المراجعة'), findsOneWidget);
  });

  testWidgets('BulkEditOperation shows "bulk edit"', (final tester) async {
    await pumpLocalized(
      tester,
      _SummaryProbe(
        BulkEditOperation(
          operationId: 'op5',
          createdAt: now,
          holdingId: 'h1',
          cityId: 'city1',
          payload: const <String, dynamic>{},
        ),
      ),
    );

    expect(find.text('تعديل جماعي (1 سجل)'), findsOneWidget);
  });
}
