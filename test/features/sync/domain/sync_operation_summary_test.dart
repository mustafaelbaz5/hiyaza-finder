import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_operation_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the real translation file straight off disk instead of through
/// `rootBundle` — see `parcel_detail_card_test.dart` for why (a real async
/// read wrapped in `Future.microtask` avoids both the `SynchronousFuture`
/// vs `Future.wait` pitfall and the "real I/O needs `runAsync`" pitfall).
class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(final String path, final Locale locale) {
    return Future.microtask(() {
      final File file = File('$path/${locale.languageCode}.json');
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  // `syncOperationSummary` calls the context-less `.tr()` extension, which
  // reads the process-wide `Localization.instance` singleton — loading
  // real translations once here (via a throwaway widget) makes it
  // available to every plain `test()` below without needing a widget per
  // case.
  testWidgets('load real translations', (final tester) async {
    // `EasyLocalization` only exposes the delegates for something else to
    // consume — without a `Localizations` widget (normally `MaterialApp`)
    // actually processing them, `delegate.load()` is never called and
    // `Localization.instance` never gets populated.
    Widget wrap(final Widget child) => EasyLocalization(
          supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
          path: 'assets/lang',
          startLocale: const Locale('ar'),
          fallbackLocale: const Locale('ar'),
          assetLoader: const _FileAssetLoader(),
          child: Builder(
            builder: (final BuildContext context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: child,
            ),
          ),
        );

    // A single pumpWidget can build before the async load resolves, and
    // with nothing above it changing identity there's nothing to force a
    // second build once it does — pumping the same content again forces
    // a fresh build against the by-then-loaded translations (see
    // parcel_detail_card_test.dart for the same pattern).
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();
  });

  test('labels an AddRecordOperation with no parentHoldingId as a new person',
      () {
    final AddRecordOperation op = AddRecordOperation(
      id: 'a',
      createdAt: DateTime(2026),
      cityId: 'c',
      record: const <String, dynamic>{'holder_name': 'محمد'},
    );

    expect(syncOperationSummary(op), contains('محمد'));
  });

  test('falls back to the unnamed label when holder_name is blank', () {
    final AddRecordOperation op = AddRecordOperation(
      id: 'a',
      createdAt: DateTime(2026),
      cityId: 'c',
      record: const <String, dynamic>{'holder_name': ''},
    );

    expect(syncOperationSummary(op), isNot(contains('محمد')));
  });

  test('labels an AddRecordOperation with a parentHoldingId as a new parcel',
      () {
    final AddRecordOperation op = AddRecordOperation(
      id: 'a',
      createdAt: DateTime(2026),
      cityId: 'c',
      parentHoldingId: 'parent-1',
      record: const <String, dynamic>{'holder_name': 'محمد'},
    );

    expect(syncOperationSummary(op), isNot(contains('محمد')));
  });

  test('includes the row count for a BulkEditOperation', () {
    final BulkEditOperation op = BulkEditOperation(
      id: 'b',
      createdAt: DateTime(2026),
      cityId: 'c',
      rows: const <BulkEditRow>[
        BulkEditRow(holdingId: 'h1', opId: 'o1', payload: <String, dynamic>{}),
        BulkEditRow(holdingId: 'h2', opId: 'o2', payload: <String, dynamic>{}),
      ],
    );

    expect(syncOperationSummary(op), contains('2'));
  });

  test('produces a non-empty label for an EditHoldingOperation', () {
    final EditHoldingOperation op = EditHoldingOperation(
      id: 'e',
      createdAt: DateTime(2026),
      cityId: 'c',
      holdingId: 'h',
      payload: const <String, dynamic>{},
    );

    expect(syncOperationSummary(op), isNotEmpty);
  });
}
