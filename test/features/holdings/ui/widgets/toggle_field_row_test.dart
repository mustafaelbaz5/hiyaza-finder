import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/toggle_field_row.dart';

import '../../../../support/localized_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalizedWidgetTestHarness);

  testWidgets('renders the label', (final tester) async {
    await pumpLocalized(
      tester,
      ToggleFieldRow(label: 'وراثة', value: false, onChanged: (final _) {}),
    );

    expect(find.text('وراثة'), findsOneWidget);
  });

  testWidgets('shows the default "yes" text when true and no activeLabel given',
      (final tester) async {
    await pumpLocalized(
      tester,
      ToggleFieldRow(label: 'وراثة', value: true, onChanged: (final _) {}),
    );

    expect(find.text('نعم'), findsOneWidget);
  });

  testWidgets('shows the default "no" text when false and no inactiveLabel given',
      (final tester) async {
    await pumpLocalized(
      tester,
      ToggleFieldRow(label: 'وراثة', value: false, onChanged: (final _) {}),
    );

    expect(find.text('لا'), findsOneWidget);
  });

  testWidgets('shows the custom activeLabel when true and given', (final tester) async {
    await pumpLocalized(
      tester,
      ToggleFieldRow(
        label: 'وراثة',
        value: true,
        activeLabel: 'وراثة',
        inactiveLabel: 'ليست وراثة',
        onChanged: (final _) {},
      ),
    );

    // Both the field label and the active state text render "وراثة" here.
    expect(find.text('وراثة'), findsNWidgets(2));
  });

  testWidgets('shows the custom inactiveLabel when false and given', (final tester) async {
    await pumpLocalized(
      tester,
      ToggleFieldRow(
        label: 'مفوض',
        value: false,
        activeLabel: 'مفوض',
        inactiveLabel: 'غير مفوض',
        onChanged: (final _) {},
      ),
    );

    expect(find.text('غير مفوض'), findsOneWidget);
  });

  testWidgets('the switch reflects value', (final tester) async {
    await pumpLocalized(
      tester,
      ToggleFieldRow(label: 'وراثة', value: true, onChanged: (final _) {}),
    );

    final Switch switchWidget = tester.widget(find.byType(Switch));
    expect(switchWidget.value, isTrue);
  });

  testWidgets('tapping the switch calls onChanged with the flipped value',
      (final tester) async {
    bool? received;
    await pumpLocalized(
      tester,
      ToggleFieldRow(
        label: 'وراثة',
        value: false,
        onChanged: (final bool v) => received = v,
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(received, isTrue);
  });

  testWidgets('shows the modified badge only when isModified is true', (final tester) async {
    await pumpLocalized(
      tester,
      ToggleFieldRow(
        label: 'وراثة',
        value: false,
        isModified: true,
        onChanged: (final _) {},
      ),
    );

    expect(find.text('تم التعديل'), findsOneWidget);
  });

  testWidgets('does not show the modified badge by default', (final tester) async {
    await pumpLocalized(
      tester,
      ToggleFieldRow(label: 'وراثة', value: false, onChanged: (final _) {}),
    );

    expect(find.text('تم التعديل'), findsNothing);
  });
}
