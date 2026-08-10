import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/home_top_bar.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_runner.dart';

import '../../../../support/localized_widget_test_harness.dart';

/// Regression test for consolidating city-level actions: the settings sheet
/// no longer links to "أدوات المدينة" — instead `HomeTopBar` exposes a
/// direct icon button that navigates to `Routes.cityTools`.
void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<SyncRunner>(SyncRunner.new);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('tapping the أدوات المدينة icon navigates to Routes.cityTools',
      (final tester) async {
    final List<String?> pushedRoutes = <String?>[];

    await tester.pumpWidget(
      wrapLocalized(
        Builder(
          builder: (final BuildContext context) => Navigator(
            onGenerateRoute: (final RouteSettings settings) {
              pushedRoutes.add(settings.name);
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (final _) => HomeTopBar(onSettings: () {}),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.build_outlined));
    await tester.pumpAndSettle();

    expect(pushedRoutes, contains(Routes.cityTools));
  });
}
