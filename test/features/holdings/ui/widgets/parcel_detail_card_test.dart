import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/parcel_detail_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the real translation file straight off disk instead of through
/// `rootBundle` — recreating [EasyLocalization] more than once in the same
/// test process (one `_wrap` call per test) makes the mocked
/// `flutter/assets` channel hang on the second+ load, so this sidesteps
/// it entirely. Two easy_localization/flutter_test pitfalls to avoid
/// here: an already-completed `SynchronousFuture` breaks `Future.wait`'s
/// bookkeeping inside easy_localization's loader-merge step (silently
/// yields empty translations), while genuinely `async` real file I/O
/// never resolves under `pump()`'s fake-async clock without
/// `tester.runAsync()`. Reading synchronously but returning it via
/// `Future.microtask` sidesteps both: it's a real (non-completed)
/// `Future`, and a microtask is exactly what the fake-async pump drives.
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

Widget _wrap(final Widget child) {
  return EasyLocalization(
    supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
    path: 'assets/lang',
    startLocale: const Locale('ar'),
    fallbackLocale: const Locale('ar'),
    assetLoader: const _FileAssetLoader(),
    child: Builder(
      builder: (final BuildContext context) => ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (final BuildContext context, final Widget? _) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
}

Future<void> _pump(final WidgetTester tester, final Widget child) async {
  await tester.pumpWidget(_wrap(child));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
  });

  const Parcel parcel = Parcel(
    id: 'p1',
    holdingId: '101',
    holderName: 'محمد علي',
    basinName: 'البشيط',
  );

  testWidgets('renders the holding id and holder name', (final tester) async {
    await _pump(
      tester,
      ParcelDetailCard(parcel: parcel, onFieldChanged: (final _) {}),
    );

    expect(find.text('101'), findsOneWidget);
    // Appears twice: اسم الحائز, and اسم المالك falls back to it when unset.
    expect(find.text('محمد علي'), findsNWidgets(2));
  });

  testWidgets(
    'shows the pending-number placeholder when holdingId is blank',
    (final tester) async {
      const Parcel newPersonParcel = Parcel(
        id: 'p2',
        holdingId: '',
        holderName: 'شخص جديد',
      );
      await _pump(
        tester,
        ParcelDetailCard(
          parcel: newPersonParcel,
          onFieldChanged: (final _) {},
        ),
      );

      expect(find.text('101'), findsNothing);
      expect(find.textContaining('بدون رقم'), findsOneWidget);
    },
  );

  testWidgets('shows the "edited" badge only when isEdited is true', (
    final tester,
  ) async {
    await _pump(
      tester,
      ParcelDetailCard(parcel: parcel, onFieldChanged: (final _) {}),
    );
    expect(find.byIcon(Icons.edit_note_rounded), findsNothing);

    await _pump(
      tester,
      ParcelDetailCard(
        parcel: parcel,
        isEdited: true,
        onFieldChanged: (final _) {},
      ),
    );
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
  });

  testWidgets('tapping the اسم المالك pencil opens the edit dialog', (
    final tester,
  ) async {
    await _pump(
      tester,
      ParcelDetailCard(parcel: parcel, onFieldChanged: (final _) {}),
    );

    final Finder editIcon = find.descendant(
      of: find.byType(ParcelDetailCard),
      matching: find.byIcon(Icons.edit_rounded),
    );
    expect(editIcon, findsWidgets);

    await tester.tap(editIcon.first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
  });
}
