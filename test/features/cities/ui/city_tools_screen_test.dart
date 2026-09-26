import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/cities/data/model/cached_city_meta.dart';
import 'package:hiyaza_finder/features/cities/data/model/city.dart';
import 'package:hiyaza_finder/features/cities/data/model/city_snapshot.dart';
import 'package:hiyaza_finder/features/cities/data/repo/city_repo.dart';
import 'package:hiyaza_finder/features/cities/ui/city_tools_screen.dart';
import 'package:hiyaza_finder/features/cities/ui/helper_tools_screen.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/parcel_catalog_repository.dart';

import '../../../support/localized_widget_test_harness.dart';

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

class _FakeCityRepo implements CityRepo {
  @override
  Future<List<City>> loadCachedPublishedCities() async => const <City>[];

  @override
  Future<void> savePublishedCities(final List<City> cities) async {}

  @override
  Future<CitySnapshot> downloadCity(final City city) =>
      throw UnimplementedError();

  @override
  Future<List<City>> listPublishedCities() => throw UnimplementedError();

  @override
  Future<CitySnapshot?> loadActiveCachedSnapshot() async => null;

  @override
  Future<CitySnapshot?> loadCachedCity(final String cityId) async => null;

  @override
  Future<void> activateCachedCity(final String cityId) async {}

  @override
  Future<int> remoteDataVersion(final String cityId) =>
      throw UnimplementedError();

  @override
  Future<List<CachedCityMeta>> listCachedCities() async =>
      const <CachedCityMeta>[];

  @override
  Future<void> deleteCachedCity(final String cityId) async {}
}

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<CityRepo>(_FakeCityRepo.new);
    getIt.registerLazySingleton<ParcelCatalogRepository>(
      () => ParcelCatalogRepository(
        editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
    'the manage-cities tile is present and navigates correctly',
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
    },
  );

  testWidgets('helper tools are moved to their dedicated screen',
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

    expect(find.text('أدوات مساعدة'), findsOneWidget);
    expect(find.text('أنواع الزرع'), findsNothing);
    expect(find.text('السجلات الناقصة لرقم الحيازة'), findsNothing);

    await tester.tap(find.text('أدوات مساعدة'));
    await tester.pumpAndSettle();

    expect(pushedRoutes, contains(Routes.helperTools));
  });

  testWidgets('helper screen displays all helper tools', (final tester) async {
    await pumpLocalizedScreen(tester, const HelperToolsScreen());
    await tester.pumpAndSettle();

    expect(find.text('أنواع الزرع'), findsOneWidget);
    expect(find.text('قائمة الملاحظات'), findsOneWidget);
    expect(find.text('السجلات الناقصة لرقم الحيازة'), findsOneWidget);
  });
}
