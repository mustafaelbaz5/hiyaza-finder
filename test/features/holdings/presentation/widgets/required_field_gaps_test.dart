import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/required_field_gaps.dart';

import '../../../../support/localized_widget_test_harness.dart';

/// `REFACTOR_ROADMAP.md` Phase 25 follow-up: رقم الحيازة joined the
/// required-field gate — verifies the real Arabic gap message shows for a
/// blank holdingId (but NOT for an explicitly-entered "-1", which is a
/// deliberately allowed value), and that the message is listed first
/// (matching the field's position at the top of `AddRecordScreen`'s form).
class _GapMessagesProbe extends StatelessWidget {
  const _GapMessagesProbe(this.parcel);

  final Parcel parcel;

  @override
  Widget build(final BuildContext context) => Column(
        children: [
          for (final String message in requiredFieldGapMessages(parcel))
            Text(message),
        ],
      );
}

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  const Parcel complete = Parcel(
    holdingId: '101',
    holderName: 'محمد علي',
    basinName: 'السرو',
    cropType: 'قمح',
    nationalId: '12345678901234',
    feddan: 2,
  );

  testWidgets('a blank holdingId shows the holding-id-required message',
      (final tester) async {
    await pumpLocalized(
      tester,
      _GapMessagesProbe(complete.copyWith(holdingId: '')),
    );
    expect(find.text('أدخل رقم الحيازة الصحيح'), findsOneWidget);
  });

  testWidgets(
      'an explicitly-entered "-1" does NOT show the holding-id-required '
      'message — it is a deliberately allowed sortable placeholder value, '
      'not one to reject', (final tester) async {
    await pumpLocalized(
      tester,
      _GapMessagesProbe(complete.copyWith(holdingId: '-1')),
    );
    expect(find.text('أدخل رقم الحيازة الصحيح'), findsNothing);
  });

  testWidgets('a missing area (feddan/qirat/sahm all null) shows the '
      'area-required message', (final tester) async {
    await pumpLocalized(
      tester,
      _GapMessagesProbe(
        complete.copyWith(feddan: null, qirat: null, sahm: null),
      ),
    );
    expect(find.text('أدخل المساحة (فدان/قيراط/سهم)'), findsOneWidget);
  });

  testWidgets('a complete parcel shows no gap messages at all', (final tester) async {
    await pumpLocalized(tester, const _GapMessagesProbe(complete));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets(
      'the holding-id message appears first, ahead of other missing fields',
      (final tester) async {
    await pumpLocalized(
      tester,
      _GapMessagesProbe(
        complete.copyWith(holdingId: '', holderName: null),
      ),
    );
    final Iterable<Text> texts = tester.widgetList<Text>(find.byType(Text));
    expect(texts.first.data, 'أدخل رقم الحيازة الصحيح');
  });
}
