import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared widget-test harness for any widget that calls `.tr()` — wraps
/// [child] in a real [EasyLocalization] (loading the actual
/// `assets/lang/*.json` files off disk, not a mock) + [ScreenUtilInit] +
/// [MaterialApp], the same setup
/// `test/features/holdings/presentation/widgets/parcel_detail_card_test.dart`
/// hand-rolled first. See [_FileAssetLoader]'s doc comment for why this
/// specific loading strategy (microtask + synchronous file read) is needed
/// to avoid easy_localization/flutter_test pitfalls.
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

Widget wrapLocalized(final Widget child, {final Locale locale = const Locale('ar')}) {
  return EasyLocalization(
    supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
    path: 'assets/lang',
    startLocale: locale,
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

Future<void> pumpLocalized(final WidgetTester tester, final Widget child) async {
  await tester.pumpWidget(wrapLocalized(child));
  await tester.pumpAndSettle();
}

/// Call once in a `setUpAll` before any test in the file uses
/// [pumpLocalized]/[wrapLocalized].
Future<void> initLocalizedWidgetTestHarness() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await EasyLocalization.ensureInitialized();
}
