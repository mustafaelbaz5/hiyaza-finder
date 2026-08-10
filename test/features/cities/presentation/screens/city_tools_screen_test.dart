import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/cached_city_meta.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city_snapshot.dart';
import 'package:hiyaza_finder/features/cities/domain/repositories/city_repository.dart';
import 'package:hiyaza_finder/features/cities/presentation/screens/city_tools_screen.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';

import '../../../../support/localized_widget_test_harness.dart';

/// Consolidation regression: "إدارة المدن المحملة" used to live only in the
/// settings sheet — it's now also (only) reachable as a tile on
/// `CityToolsScreen`, alongside missing-holding-id and crop-types.
class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> getString(final String key) async => _store[key];

  @override
  Future<void> remove(final String key) async => _store.remove(key);

  @override
  Future<void> setString(final String key, final String value) async {
    _store[key] = value;
  }
}

class _FakeCityRepository implements CityRepository {
  @override
  Future<CitySnapshot> downloadCity(final City city) => throw UnimplementedError();

  @override
  Future<List<City>> listPublishedCities() => throw UnimplementedError();

  @override
  Future<CitySnapshot?> loadActiveCachedSnapshot() async => null;

  @override
  Future<int> remoteDataVersion(final String cityId) => throw UnimplementedError();

  @override
  Future<List<CachedCityMeta>> listCachedCities() async => const <CachedCityMeta>[];

  @override
  Future<void> deleteCachedCity(final String cityId) async {}

  @override
  Future<City> fetchCity(final String cityId) => throw UnimplementedError();

  @override
  Future<void> updateCityCode(final String cityId, final String? code) =>
      throw UnimplementedError();
}

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<CityRepository>(_FakeCityRepository.new);
    getIt.registerLazySingleton<HoldingsRepository>(
      () => HoldingsRepository(
        editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'the manage-cities tile is present and navigates to Routes.manageCities',
      (final tester) async {
    final List<String?> pushedRoutes = <String?>[];

    await tester.pumpWidget(
      wrapLocalizedScreen(
        Navigator(
          onGenerateRoute: (final RouteSettings settings) {
            pushedRoutes.add(settings.name);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (final _) => const CityToolsScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إدارة المدن المحملة'), findsOneWidget);

    await tester.tap(find.text('إدارة المدن المحملة'));
    await tester.pumpAndSettle();

    expect(pushedRoutes, contains(Routes.manageCities));
  });

  testWidgets('missing-holding-id and crop-types tiles are still present',
      (final tester) async {
    await pumpLocalizedScreen(tester, const CityToolsScreen());
    await tester.pumpAndSettle();

    expect(find.text('السجلات الناقصة لرقم الحيازة'), findsOneWidget);
    expect(find.text('أنواع الزرع'), findsOneWidget);
  });
}
