import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/holdings/data/local/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/holdings/data/repo/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/ui/add_record_screen.dart';

import '../../../support/localized_widget_test_harness.dart';

/// `add_record_screen.dart` was trimmed down to a fixed field list per the
/// user's request (رقم الحيازة, اسم الحائز, اسم الحوض, رقم الأرض, المساحة,
/// نوع الزرع, الملاحظات, الرقم القومي [new-person only], وراثة/مفوض toggles)
/// — عدد القطع/نوع الائتمان/نوع الاستخدام/مراحل النمو are no longer shown.
/// اسم المالك now only appears once مفوض is toggled on, rather than always.
class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> getString(final String key) async => _store[key];

  @override
  Future<void> remove(final String key) async => _store.remove(key);

  @override
  Future<void> setString(final String key, final String value) async {
    _store[key] = value;
  }
}

Future<void> _registerRepository() async {
  await getIt.reset();
  final HoldingsRepository repository = HoldingsRepository(
    editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
  );
  await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  getIt.registerLazySingleton<HoldingsRepository>(() => repository);
}

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'اسم المالك is hidden until مفوض is toggled on, for both new-person '
      'and new-parcel-for-existing-person flows', (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(holdingId: ''),
      ),
    );

    expect(find.text('اسم المالك'), findsNothing);

    final Finder delegateSwitch = find.byType(Switch).last;
    await tester.tap(delegateSwitch);
    await tester.pumpAndSettle();

    expect(find.text('اسم المالك'), findsOneWidget);

    await tester.tap(delegateSwitch);
    await tester.pumpAndSettle();

    expect(find.text('اسم المالك'), findsNothing);
  });

  testWidgets('عدد القطع/نوع الائتمان/نوع الاستخدام/مراحل النمو are no '
      'longer shown on the trimmed form', (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(holdingId: ''),
      ),
    );

    expect(find.text('نوع الائتمان'), findsNothing);
    expect(find.text('نوع الاستخدام'), findsNothing);
    expect(find.text('مراحل النمو'), findsNothing);
  });

  testWidgets('الرقم القومي only shows for the new-person flow '
      '(parentHoldingId == null)', (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(holdingId: ''),
      ),
    );
    expect(find.text('الرقم القومي'), findsOneWidget);

    await _registerRepository();
    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(id: 'p1', holdingId: '', holderName: 'أحمد'),
        parentHoldingId: 'p1',
      ),
    );
    expect(find.text('الرقم القومي'), findsNothing);
  });
}
