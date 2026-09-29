import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/parcel_add/ui/add_record_screen.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/parcel_catalog_repository.dart';

import '../../../support/localized_widget_test_harness.dart';

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

Future<void> _registerRepository(
    [final List<Parcel> parcels = const <Parcel>[]]) async {
  await getIt.reset();
  final ParcelCatalogRepository repository = ParcelCatalogRepository(
    editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
  );
  await repository.loadParcelsForCity('city-1', parcels);
  getIt.registerLazySingleton<ParcelCatalogRepository>(() => repository);
}

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'اسم المالك is hidden until مفوض is confirmed via its dialog, and '
      'reappears hidden again once toggled back off', (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(holdingId: '', holderName: 'محمد'),
      ),
    );

    expect(find.text('اسم المالك'), findsNothing);

    final Finder delegateSwitch = find.byType(Switch).last;
    await tester.tap(delegateSwitch);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'احمد');
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('حفظ'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اسم المالك'), findsOneWidget);

    await tester.tap(delegateSwitch);
    await tester.pumpAndSettle();

    expect(find.text('اسم المالك'), findsNothing);
  });

  testWidgets(
      'عدد القطع/نوع الائتمان/مراحل النمو are no longer shown on the trimmed form',
      (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(initialParcel: Parcel(holdingId: '')),
    );

    expect(find.text('نوع الائتمان'), findsNothing);
    expect(find.text('مراحل النمو'), findsNothing);
  });

  testWidgets(
      'الرقم القومي only shows for the new-person flow '
      '(parentHoldingId == null)', (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(initialParcel: Parcel(holdingId: '')),
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

  testWidgets('uses the suggested Jazla basin as the editable initial value',
      (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(holdingId: '', holderName: 'محمد'),
        suggestedBasinName: 'حوض الجزلة',
        suggestedBasinCode: 'B-7',
      ),
    );

    expect(find.text('حوض الجزلة'), findsOneWidget);

    await tester.tap(find.text('حوض الجزلة'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('requires selecting a holder when a holding has multiple people',
      (final tester) async {
    await _registerRepository(const <Parcel>[
      Parcel(
        id: 'one',
        holdingId: '42',
        holderName: 'أحمد علي',
        nationalId: '11111111111111',
      ),
      Parcel(
        id: 'two',
        holdingId: '42',
        holderName: 'محمود حسن',
        nationalId: '22222222222222',
      ),
    ]);

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(initialParcel: Parcel(holdingId: '')),
    );

    await tester.tap(find.text('شخص موجود'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '42');
    await tester.pumpAndSettle();

    expect(find.text('اختر الحائز المطلوب'), findsOneWidget);
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('محمود حسن'), findsOneWidget);

    final FilledButton beforeSelection = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(beforeSelection.onPressed, isNull);

    await tester.tap(find.text('محمود حسن'));
    await tester.pump();

    final FilledButton afterSelection = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(afterSelection.onPressed, isNotNull);
  });
}
