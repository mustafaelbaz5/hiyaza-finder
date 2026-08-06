import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/cached_city_meta.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city.dart';
import 'package:hiyaza_finder/features/cities/domain/entities/city_snapshot.dart';
import 'package:hiyaza_finder/features/cities/domain/repositories/city_repository.dart';
import 'package:hiyaza_finder/features/cities/presentation/screens/manage_cities_screen.dart';

import '../../../../support/localized_widget_test_harness.dart';

class _FakeCityRepository implements CityRepository {
  List<CachedCityMeta> cachedCities = const <CachedCityMeta>[];
  bool throwOnList = false;
  final List<String> deletedCityIds = <String>[];

  @override
  Future<List<CachedCityMeta>> listCachedCities() async {
    if (throwOnList) throw Exception('boom');
    return cachedCities;
  }

  @override
  Future<CitySnapshot?> loadActiveCachedSnapshot() async => null;

  @override
  Future<void> deleteCachedCity(final String cityId) async {
    deletedCityIds.add(cityId);
    cachedCities =
        cachedCities.where((final CachedCityMeta c) => c.cityId != cityId).toList();
  }

  @override
  Future<CitySnapshot> downloadCity(final City city) => throw UnimplementedError();

  @override
  Future<List<City>> listPublishedCities() => throw UnimplementedError();

  @override
  Future<int> remoteDataVersion(final String cityId) => throw UnimplementedError();
}

CachedCityMeta _city(final String id, final String name) => CachedCityMeta(
      cityId: id,
      cityName: name,
      dataVersion: 1,
      downloadedAt: DateTime(2026),
      parcelsCount: 10,
      fileSizeBytes: 2048,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalizedWidgetTestHarness);

  late _FakeCityRepository repository;

  setUp(() async {
    await getIt.reset();
    repository = _FakeCityRepository();
    getIt.registerLazySingleton<CityRepository>(() => repository);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('shows the empty state when there are no cached cities',
      (final tester) async {
    await pumpLocalizedScreen(tester, const ManageCitiesScreen());
    await tester.pumpAndSettle();

    expect(find.text('لا توجد مدن محمّلة على الجهاز'), findsOneWidget);
  });

  testWidgets('lists cached cities with their summary', (final tester) async {
    repository.cachedCities = <CachedCityMeta>[_city('c1', 'مدينة الاختبار')];

    await pumpLocalizedScreen(tester, const ManageCitiesScreen());
    await tester.pumpAndSettle();

    expect(find.text('مدينة الاختبار'), findsOneWidget);
  });

  testWidgets('shows an error state when loading fails', (final tester) async {
    repository.throwOnList = true;

    await pumpLocalizedScreen(tester, const ManageCitiesScreen());
    await tester.pumpAndSettle();

    expect(find.text('حدث خطأ غير متوقع.'), findsOneWidget);
  });
}
