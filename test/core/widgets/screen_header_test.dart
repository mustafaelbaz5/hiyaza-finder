import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/widgets/screen_header.dart';

import '../../support/localized_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalizedWidgetTestHarness);

  testWidgets('renders the given title', (final tester) async {
    await pumpLocalized(tester, const ScreenHeader(title: 'عنوان الشاشة'));

    expect(find.text('عنوان الشاشة'), findsOneWidget);
  });

  testWidgets('shows a back button', (final tester) async {
    await pumpLocalized(tester, const ScreenHeader(title: 'عنوان'));

    expect(find.byIcon(Icons.arrow_back_ios_new_outlined), findsOneWidget);
  });

  testWidgets('calls onBack when the back button is tapped', (final tester) async {
    int tapCount = 0;
    await pumpLocalized(
      tester,
      ScreenHeader(title: 'عنوان', onBack: () => tapCount++),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_outlined));
    await tester.pump();

    expect(tapCount, 1);
  });
}
