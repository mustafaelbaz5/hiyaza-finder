import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/networking/connection_quality_service.dart';
import 'package:hiyaza_finder/core/networking/network_info.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/home_top_bar.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_runner.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../../../support/localized_widget_test_harness.dart';

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<InternetConnectionStatus> get onStatusChange => const Stream.empty();
}

/// Regression test for consolidating city-level actions: the settings sheet
/// no longer links to "أدوات المدينة" — instead `HomeTopBar` exposes a
/// direct icon button that navigates to `Routes.cityTools`.
void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<SyncRunner>(SyncRunner.new);
    getIt.registerLazySingleton<ConnectionQualityService>(
      () => ConnectionQualityService(_FakeNetworkInfo()),
    );
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

  testWidgets('shows a wifi-off icon when the connectivity service reports '
      'offline', (final tester) async {
    await getIt.reset();
    getIt.registerLazySingleton<SyncRunner>(SyncRunner.new);
    // Uses `checkNow()` instead of `start()` — a running `Timer.periodic`
    // would make `pumpAndSettle` (which waits out every pending timer) hang
    // forever, so this test avoids starting the poll loop entirely and just
    // triggers one classification pass directly.
    final ConnectionQualityService service = ConnectionQualityService(
      _OfflineNetworkInfo(),
    );
    await service.checkNow();
    getIt.registerLazySingleton<ConnectionQualityService>(() => service);

    await tester.pumpWidget(wrapLocalized(HomeTopBar(onSettings: () {})));
    await tester.pump();

    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wifi_rounded), findsNothing);

    service.dispose();
  });

  testWidgets('shows a wifi icon when the connectivity service reports '
      'strong', (final tester) async {
    await tester.pumpWidget(wrapLocalized(HomeTopBar(onSettings: () {})));
    await tester.pump();

    expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
  });
}

class _OfflineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<InternetConnectionStatus> get onStatusChange => const Stream.empty();
}
