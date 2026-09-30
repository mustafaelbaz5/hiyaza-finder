import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/home/ui/widgets/home_main_card.dart';

import '../../../../support/localized_widget_test_harness.dart';

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  HomeMainCard buildCard({
    final String? cityName,
    final VoidCallback? onChangeCity,
    final VoidCallback? onOpenJazla,
    final VoidCallback? onOpenSearchFilter,
  }) {
    return HomeMainCard(
      cityName: cityName ?? 'جمعية اختبار',
      onChangeCity: onChangeCity ?? () {},
      onOpenJazla: onOpenJazla ?? () {},
      onOpenSearchFilter: onOpenSearchFilter ?? () {},
    );
  }

  testWidgets('shows association identity and compact quick actions',
      (final WidgetTester tester) async {
    await pumpLocalized(tester, buildCard());

    expect(find.text('جمعية اختبار'), findsOneWidget);
    expect(find.text('قطع فعّالة'), findsNothing);
    expect(find.text('إجمالي السجلات'), findsNothing);
    expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
    expect(find.byIcon(Icons.handyman_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
  });

  testWidgets('quick actions invoke Jazla, filter, and city picker callbacks',
      (final WidgetTester tester) async {
    bool jazlaTapped = false;
    bool filterTapped = false;
    bool cityPickerTapped = false;
    await pumpLocalized(
      tester,
      buildCard(
        onOpenJazla: () => jazlaTapped = true,
        onOpenSearchFilter: () => filterTapped = true,
        onChangeCity: () => cityPickerTapped = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.layers_rounded));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.tap(find.byIcon(Icons.swap_horiz_rounded));

    expect(jazlaTapped, isTrue);
    expect(filterTapped, isTrue);
    expect(cityPickerTapped, isTrue);
  });

  testWidgets('city tools action opens the existing route',
      (final WidgetTester tester) async {
    final List<String?> pushedRoutes = <String?>[];
    await tester.pumpWidget(
      wrapLocalized(
        Navigator(
          onGenerateRoute: (final RouteSettings settings) {
            pushedRoutes.add(settings.name);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (final BuildContext _) => buildCard(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.handyman_rounded));
    await tester.pumpAndSettle();

    expect(pushedRoutes, contains(Routes.cityTools));
  });

  testWidgets('wraps a long association name within a narrow phone layout',
      (final WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpLocalized(
      tester,
      buildCard(
        cityName:
            'جمعية منشأة الإخوة للإصلاح الزراعي بمحافظة الدقهلية وإدارة أجا',
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
