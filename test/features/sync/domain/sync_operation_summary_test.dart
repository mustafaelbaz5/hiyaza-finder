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

  testWidgets('CompleteParcelOperation shows "reviewed status update"',
      (final tester) async {
    await pumpLocalized(
      tester,
      _SummaryProbe(
        CompleteParcelOperation(
          operationId: 'op4',
          createdAt: now,
          parcelId: 'p1',
          isFieldAdded: true,
          completed: true,
          completedAt: now,
          completedByUserId: 'user1',
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

  group('syncOperationTargetParcel', () {
    test(
        'returns null for AddParcelOperation — it already carries the full '
        'Parcel itself, so callers should read op.parcel directly instead '
        'of going through this dataset lookup', () {
      final AddParcelOperation op = AddParcelOperation(
        operationId: 'op1',
        createdAt: now,
        cityId: 'city1',
        parcel: const Parcel(id: 'p1', holdingId: '101', holderName: 'محمد'),
        parentHoldingId: null,
      );

      expect(syncOperationTargetParcel(op, const <Parcel>[]), isNull);
    });

    test('looks up CompleteParcelOperation.parcelId in the given dataset',
        () {
      final CompleteParcelOperation op = CompleteParcelOperation(
        operationId: 'op4',
        createdAt: now,
        parcelId: 'p1',
        isFieldAdded: false,
        completed: true,
        completedAt: now,
        completedByUserId: 'user1',
      );
      const List<Parcel> dataset = <Parcel>[
        Parcel(id: 'p1', holdingId: '101', holderName: 'سعيد'),
        Parcel(id: 'p2', holdingId: '102', holderName: 'ياسر'),
      ];

      final Parcel? target = syncOperationTargetParcel(op, dataset);
      expect(target?.holderName, 'سعيد');
    });

    test('returns null when the target parcel is not in the given dataset '
        '(e.g. a different city is now loaded)', () {
      final CompleteParcelOperation op = CompleteParcelOperation(
        operationId: 'op4',
        createdAt: now,
        parcelId: 'missing',
        isFieldAdded: false,
        completed: true,
        completedAt: now,
        completedByUserId: 'user1',
      );

      expect(syncOperationTargetParcel(op, const <Parcel>[]), isNull);
    });
  });

  group('syncOperationDetailLine', () {
    testWidgets(
        'includes the holder name, holding id, queued-at time, and attempt '
        'count', (final tester) async {
      final CompleteParcelOperation op = CompleteParcelOperation(
        operationId: 'op4',
        createdAt: DateTime(2026, 8, 6, 14, 30),
        parcelId: 'p1',
        isFieldAdded: false,
        completed: true,
        completedAt: now,
        completedByUserId: 'user1',
      ).withAttempt(error: 'conflict');
      const List<Parcel> dataset = <Parcel>[
        Parcel(id: 'p1', holdingId: '101', holderName: 'سعيد'),
      ];

      await pumpLocalized(
        tester,
        Builder(
          builder: (final BuildContext context) =>
              Text(syncOperationDetailLine(op, dataset)),
        ),
      );

      expect(find.textContaining('سعيد'), findsOneWidget);
      expect(find.textContaining('#101'), findsOneWidget);
      expect(find.textContaining('2026-08-06 14:30'), findsOneWidget);
      expect(find.textContaining('1 محاولة'), findsOneWidget);
    });

    testWidgets('falls back to "unnamed" and omits the holding id when the '
        'target parcel cannot be found', (final tester) async {
      final CompleteParcelOperation op = CompleteParcelOperation(
        operationId: 'op4',
        createdAt: now,
        parcelId: 'missing',
        isFieldAdded: false,
        completed: true,
        completedAt: now,
        completedByUserId: 'user1',
      );

      await pumpLocalized(
        tester,
        Builder(
          builder: (final BuildContext context) =>
              Text(syncOperationDetailLine(op, const <Parcel>[])),
        ),
      );

      expect(find.textContaining('بدون اسم'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
    });
  });
}
