import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/home/ui/widgets/home_main_card.dart';

import '../../../../support/localized_widget_test_harness.dart';

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  HomeMainCard buildCard({
    final VoidCallback? onChangeCity,
    final VoidCallback? onOpenJazla,
    final VoidCallback? onOpenSearchFilter,
  }) {
    return HomeMainCard(
      cityName: 'جمعية اختبار',
      parcelCount: 24,
      onChangeCity: onChangeCity ?? () {},
      onOpenJazla: onOpenJazla ?? () {},
      onOpenSearchFilter: onOpenSearchFilter ?? () {},
    );
  }

  testWidgets('shows city summary and the three quick actions',
      (final tester) async {
    await pumpLocalized(tester, buildCard());

    expect(find.text('جمعية اختبار'), findsOneWidget);
    expect(find.text('قطع فعّالة'), findsOneWidget);
    expect(find.text('إجمالي السجلات'), findsOneWidget);
    expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
    expect(find.byIcon(Icons.build_outlined), findsOneWidget);
    expect(find.byIcon(Icons.change_circle_outlined), findsOneWidget);
  });

  testWidgets('quick actions invoke Jazla and city picker callbacks',
      (final tester) async {
    bool jazlaTapped = false;
    bool cityPickerTapped = false;
    await pumpLocalized(
      tester,
      buildCard(
        onOpenJazla: () => jazlaTapped = true,
        onChangeCity: () => cityPickerTapped = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.tap(find.byIcon(Icons.change_circle_outlined));

    expect(jazlaTapped, isTrue);
    expect(cityPickerTapped, isTrue);
  });

  testWidgets('city tools action opens the existing route',
      (final tester) async {
    final List<String?> pushedRoutes = <String?>[];
    await tester.pumpWidget(
      wrapLocalized(
        Navigator(
          onGenerateRoute: (final RouteSettings settings) {
            pushedRoutes.add(settings.name);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (final _) => buildCard(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.build_outlined));
    await tester.pumpAndSettle();

    expect(pushedRoutes, contains(Routes.cityTools));
  });

  testWidgets('stays within a narrow phone layout without overflow',
      (final tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpLocalized(tester, buildCard());

    expect(tester.takeException(), isNull);
  });
}
