import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/holdings/data/repo/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/home_top_bar.dart';

import '../../../../support/localized_widget_test_harness.dart';

/// `HomeTopBar` no longer shows a connectivity indicator or a basin-filter
/// icon (APP_UPDATES_CLAUDE.md § 9.1/9.4) — just the three navigation
/// icons: basins page, city tools, and change city (a direct callback,
/// since Home owns the city-picker flow itself). It also now reads the
/// active city's name/association type directly from `HoldingsRepository`
/// (UI/UX Updates prompt "Change 3"), so every test registers one via
/// `getIt` before pumping.
void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<HoldingsRepository>(HoldingsRepository.new);
  });

  Future<List<String?>> _pumpAndCapturePushedRoutes(
    final WidgetTester tester, {
    required final VoidCallback onChangeCity,
  }) async {
    final List<String?> pushedRoutes = <String?>[];
    await tester.pumpWidget(
      wrapLocalized(
        Builder(
          builder: (final BuildContext context) => Navigator(
            onGenerateRoute: (final RouteSettings settings) {
              pushedRoutes.add(settings.name);
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (final _) => HomeTopBar(onChangeCity: onChangeCity),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return pushedRoutes;
  }

  testWidgets('tapping the basins icon navigates to Routes.basins',
      (final tester) async {
    final List<String?> pushedRoutes =
        await _pumpAndCapturePushedRoutes(tester, onChangeCity: () {});

    await tester.tap(find.byIcon(Icons.holiday_village_rounded));
    await tester.pumpAndSettle();

    expect(pushedRoutes, contains(Routes.basins));
  });

  testWidgets('tapping the city tools icon navigates to Routes.cityTools',
      (final tester) async {
    final List<String?> pushedRoutes =
        await _pumpAndCapturePushedRoutes(tester, onChangeCity: () {});

    await tester.tap(find.byIcon(Icons.build_outlined));
    await tester.pumpAndSettle();

    expect(pushedRoutes, contains(Routes.cityTools));
  });

  testWidgets('tapping the change-city icon calls onChangeCity',
      (final tester) async {
    bool changeCityTapped = false;
    await tester.pumpWidget(
      wrapLocalized(
        HomeTopBar(onChangeCity: () => changeCityTapped = true),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
    await tester.pump();

    expect(changeCityTapped, isTrue);
  });

  testWidgets('shows no connectivity indicator', (final tester) async {
    await tester.pumpWidget(wrapLocalized(HomeTopBar(onChangeCity: () {})));
    await tester.pump();

    expect(find.byIcon(Icons.wifi_rounded), findsNothing);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
  });
}
