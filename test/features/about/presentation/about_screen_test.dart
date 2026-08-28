import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/about/presentation/about_screen.dart';

import '../../../support/localized_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalizedWidgetTestHarness);

  testWidgets('renders the section labels', (final tester) async {
    await pumpLocalizedScreen(tester, const AboutScreen());

    expect(find.text('معلومات التطبيق'), findsOneWidget);
    expect(find.text('المطور'), findsOneWidget);
    expect(find.text('الدعم'), findsOneWidget);
  });

  testWidgets('shows a back button', (final tester) async {
    await pumpLocalizedScreen(tester, const AboutScreen());

    expect(find.byIcon(Icons.arrow_back_ios_new_outlined), findsOneWidget);
  });
}
