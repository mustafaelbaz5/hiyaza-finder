import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/field_row.dart';

import '../../../../support/localized_widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalizedWidgetTestHarness);

  testWidgets('renders the label and value', (final tester) async {
    await pumpLocalized(
      tester,
      const FieldRow(label: 'اسم الحائز', value: 'محمد علي'),
    );

    expect(find.text('اسم الحائز'), findsOneWidget);
    expect(find.text('محمد علي'), findsOneWidget);
  });

  testWidgets('shows the default placeholder for a null value', (final tester) async {
    await pumpLocalized(
      tester,
      const FieldRow(label: 'اسم الحائز', value: null),
    );

    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('shows the default placeholder for a blank value', (final tester) async {
    await pumpLocalized(
      tester,
      const FieldRow(label: 'اسم الحائز', value: '   '),
    );

    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('shows a custom placeholder when given', (final tester) async {
    await pumpLocalized(
      tester,
      const FieldRow(label: 'كود الحوض', value: null, placeholder: '-1'),
    );

    expect(find.text('-1'), findsOneWidget);
  });

  testWidgets('shows the modified badge only when isModified is true', (final tester) async {
    await pumpLocalized(
      tester,
      const FieldRow(label: 'اسم الحائز', value: 'محمد', isModified: true),
    );

    expect(find.text('تم التعديل'), findsOneWidget);
  });

  testWidgets('does not show the modified badge by default', (final tester) async {
    await pumpLocalized(
      tester,
      const FieldRow(label: 'اسم الحائز', value: 'محمد'),
    );

    expect(find.text('تم التعديل'), findsNothing);
  });

  testWidgets('shows an edit icon only when onEdit is provided', (final tester) async {
    await pumpLocalized(
      tester,
      FieldRow(label: 'اسم الحائز', value: 'محمد', onEdit: () {}),
    );

    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
  });

  testWidgets('does not show an edit icon when onEdit is null', (final tester) async {
    await pumpLocalized(
      tester,
      const FieldRow(label: 'اسم الحائز', value: 'محمد'),
    );

    expect(find.byIcon(Icons.edit_rounded), findsNothing);
  });

  testWidgets('always shows the copy icon', (final tester) async {
    await pumpLocalized(
      tester,
      const FieldRow(label: 'اسم الحائز', value: 'محمد'),
    );

    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('tapping edit calls onEdit', (final tester) async {
    int tapCount = 0;
    await pumpLocalized(
      tester,
      FieldRow(label: 'اسم الحائز', value: 'محمد', onEdit: () => tapCount++),
    );

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('tapping copy shows a success snackbar', (final tester) async {
    // Clipboard.setData goes through the platform channel — mock it so the
    // await inside FieldRow's _copy resolves instead of hanging under
    // pumpAndSettle.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (final MethodCall call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpLocalized(
      tester,
      const FieldRow(label: 'اسم الحائز', value: 'محمد'),
    );

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pumpAndSettle();

    expect(find.text('تم النسخ'), findsOneWidget);
  });
}
