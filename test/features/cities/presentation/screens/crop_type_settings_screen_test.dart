import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/cities/domain/repositories/crop_type_repository.dart';
import 'package:hiyaza_finder/features/cities/presentation/screens/crop_type_settings_screen.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';

import '../../../../support/localized_widget_test_harness.dart';

/// Regression coverage for the RLS-rejection bugs: previously a rejected
/// delete threw nothing (looked like success, then the item reappeared on
/// the next fetch) and a rejected add showed a generic error. Both are now
/// modeled here via a fake repository that can be told to reject writes —
/// the screen must not optimistically apply a change the repository threw
/// on.
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

class _FakeCropTypeRepository implements CropTypeRepository {
  List<String> cropTypes = <String>[];
  bool shouldFailWrites = false;

  @override
  Future<List<String>> fetchCropTypes(final String cityId) async => cropTypes;

  @override
  Future<void> addCropType(final String cityId, final String cropType) async {
    if (shouldFailWrites) throw Exception('RLS rejected the write');
    cropTypes = <String>[...cropTypes, cropType];
  }

  @override
  Future<void> removeCropType(final String cityId, final String cropType) async {
    if (shouldFailWrites) throw Exception('RLS rejected the write');
    cropTypes = cropTypes.where((final String c) => c != cropType).toList();
  }
}

Future<void> _register(final _FakeCropTypeRepository repository) async {
  await getIt.reset();
  getIt.registerLazySingleton<CropTypeRepository>(() => repository);
  final HoldingsRepository holdingsRepository = HoldingsRepository(
    editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
  );
  await holdingsRepository.loadParcelsForCity('city-1', const []);
  getIt.registerLazySingleton<HoldingsRepository>(() => holdingsRepository);
}

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'a delete rejected by the repository shows an error and the item '
      'stays in the list — never optimistically removed', (final tester) async {
    final _FakeCropTypeRepository repository = _FakeCropTypeRepository()
      ..cropTypes = <String>['قمح', 'ارز']
      ..shouldFailWrites = true;
    await _register(repository);

    await pumpLocalizedScreen(tester, const CropTypeSettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('قمح'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('نعم'));
    await tester.pumpAndSettle();

    expect(find.text('قمح'), findsOneWidget);
    expect(find.text('حدث خطأ غير متوقع.'), findsOneWidget);
  });

  testWidgets(
      'a delete that succeeds actually removes the item from the list',
      (final tester) async {
    final _FakeCropTypeRepository repository = _FakeCropTypeRepository()
      ..cropTypes = <String>['قمح', 'ارز'];
    await _register(repository);

    await pumpLocalizedScreen(tester, const CropTypeSettingsScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('نعم'));
    await tester.pumpAndSettle();

    expect(find.text('قمح'), findsNothing);
    expect(find.text('ارز'), findsOneWidget);
  });
}
