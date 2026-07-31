import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/router/app_router.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city_snapshot.dart';

void main() {
  // Regression test: `context.pushNamed<CitySnapshot>(Routes.cityPicker)`
  // makes the Navigator internally cast whatever `onGenerateRoute` returns
  // to `Route<CitySnapshot>?`. `_buildRoute` previously wasn't generic, so
  // it always built a `PageRouteBuilder<dynamic>` — that cast threw
  // `_TypeError` at runtime (never caught by `flutter analyze`, since the
  // mismatch only exists at the reified-generic level).
  test(
    'the city picker route can be cast to Route<CitySnapshot>, matching '
    "what pushNamed<CitySnapshot> requires at runtime",
    () {
      final Route<dynamic>? route = AppRouter.generateRoute(
        const RouteSettings(name: Routes.cityPicker),
      );
      expect(route, isNotNull);
      expect(() => route! as Route<CitySnapshot>, returnsNormally);
    },
  );

  test('every named route resolves to a non-null Route', () {
    for (final String name in <String>[
      Routes.aboutScreen,
      Routes.login,
      Routes.cityPicker,
      Routes.home,
      Routes.fileStatus,
    ]) {
      final Route<dynamic>? route = AppRouter.generateRoute(
        RouteSettings(name: name),
      );
      expect(route, isNotNull, reason: '$name did not resolve to a route');
    }
  });
}
