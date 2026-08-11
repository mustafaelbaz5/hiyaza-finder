import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/screens/missing_holding_id_screen.dart';
import 'package:hiyaza_finder/features/sync/data/holdings_api.dart';

import '../../../../support/localized_widget_test_harness.dart';

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

class _FakeHoldingsApi implements HoldingsApi {
  @override
  Future<({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})>
      searchRemote({required final String cityId, required final String query}) async =>
          (holdings: const <Map<String, dynamic>>[], addedHoldings: const <Map<String, dynamic>>[]);

  @override
  Future<({Map<String, dynamic> row, bool isFieldAdded})?> fetchParcelById(
    final String id, {
    final bool? isFieldAdded,
  }) async =>
      null;

  @override
  Future<String?> addRecord({
    required final String id,
    required final String cityId,
    required final Map<String, dynamic> record,
    required final String? parentHoldingId,
    required final String createdByUserId,
  }) async =>
      null;

  @override
  Future<void> deleteAddedHolding(final String id) async {}

  @override
  Future<Map<String, String>> fetchProfileEmails(
    final Iterable<String> profileIds,
  ) async =>
      const <String, String>{};

  @override
  Future<void> editHolding({
    required final String holdingId,
    required final String cityId,
    required final Map<String, dynamic> payload,
    required final String editedByUserId,
  }) async {}

  @override
  Future<List<String>> bulkEditHoldings({
    required final String cityId,
    required final Map<String, Map<String, dynamic>> payloadsByHoldingId,
    required final String editedByUserId,
  }) async =>
      const <String>[];

  @override
  Future<void> markCompleted({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool completed,
    required final DateTime? completedAt,
    required final String completedByUserId,
  }) async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => const AppUser(
        id: 'user-1',
        email: 'field@example.com',
        displayName: 'Field Worker',
        role: UserRole.field,
      );

  @override
  Stream<AppUser?> get userChanges => const Stream<AppUser?>.empty();

  @override
  Future<AppUser> signInWithPassword({
    required final String email,
    required final String password,
  }) async =>
      currentUser!;

  @override
  Future<void> signOut() async {}
}

Future<void> _registerRepository(final List<Parcel> parcels) async {
  await getIt.reset();
  getIt.registerLazySingleton<AuthRepository>(_FakeAuthRepository.new);
  final HoldingsRepository repository = HoldingsRepository(
    editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
    holdingsApi: _FakeHoldingsApi(),
  );
  await repository.loadParcelsForCity('city-1', parcels);
  getIt.registerLazySingleton<HoldingsRepository>(() => repository);
}

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('shows the empty state when every parcel already has a '
      'holding number', (final tester) async {
    await _registerRepository(const <Parcel>[
      Parcel(id: 'p1', holdingId: '101', holderName: 'أحمد'),
      Parcel(id: 'p2', holdingId: '102', holderName: 'محمد'),
    ]);

    await pumpLocalizedScreen(tester, const MissingHoldingIdScreen());

    expect(find.text('لا توجد سجلات ناقصة رقم الحيازة'), findsOneWidget);
  });

  testWidgets(
      'lists only parcels whose holdingId is blank, "-1", or "0" — not real '
      'numbers', (final tester) async {
    await _registerRepository(const <Parcel>[
      Parcel(id: 'p1', holdingId: '101', holderName: 'أحمد كامل'),
      Parcel(id: 'p2', holdingId: '', holderName: 'سعيد فتحي'),
      Parcel(id: 'p3', holdingId: '-1', holderName: 'ياسر عادل'),
      Parcel(id: 'p4', holdingId: '0', holderName: 'كريم سالم'),
    ]);

    await pumpLocalizedScreen(tester, const MissingHoldingIdScreen());

    expect(find.textContaining('سعيد فتحي'), findsOneWidget);
    expect(find.textContaining('ياسر عادل'), findsOneWidget);
    expect(find.textContaining('كريم سالم'), findsOneWidget);
    expect(find.textContaining('أحمد كامل'), findsNothing);
  });

  testWidgets(
      'two different people who both have holdingId "0" are NOT merged '
      'into one result — "0" is not treated as a shared placeholder',
      (final tester) async {
    await _registerRepository(const <Parcel>[
      Parcel(id: 'p1', holdingId: '0', holderName: 'الأول'),
      Parcel(id: 'p2', holdingId: '0', holderName: 'الثاني'),
    ]);

    await pumpLocalizedScreen(tester, const MissingHoldingIdScreen());

    expect(find.textContaining('الأول'), findsOneWidget);
    expect(find.textContaining('الثاني'), findsOneWidget);
    expect(find.text('2 حيازة'), findsOneWidget);
  });

  testWidgets(
      'tapping a "0"-holdingId result opens the detail screen with only '
      'that person\'s own parcel(s)', (final tester) async {
    await _registerRepository(const <Parcel>[
      Parcel(id: 'p1', holdingId: '0', holderName: 'الأول'),
      Parcel(id: 'p2', holdingId: '0', holderName: 'الثاني'),
    ]);

    final List<String?> pushedRoutes = <String?>[];
    List<Parcel>? pushedArgs;

    await tester.pumpWidget(
      wrapLocalizedScreen(
        Navigator(
          onGenerateRoute: (final RouteSettings settings) {
            pushedRoutes.add(settings.name);
            pushedArgs = settings.arguments as List<Parcel>?;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (final _) => const MissingHoldingIdScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('الأول'));
    await tester.pumpAndSettle();

    expect(pushedRoutes, contains(Routes.holdingDetail));
    expect(pushedArgs, isNotNull);
    expect(pushedArgs!.map((final Parcel p) => p.id), <String>['p1']);
  });

  testWidgets('typing in the search field filters the list by name',
      (final tester) async {
    await _registerRepository(const <Parcel>[
      Parcel(id: 'p1', holdingId: '', holderName: 'سعيد فتحي'),
      Parcel(id: 'p2', holdingId: '-1', holderName: 'ياسر عادل'),
    ]);

    await pumpLocalizedScreen(tester, const MissingHoldingIdScreen());
    expect(find.textContaining('سعيد فتحي'), findsOneWidget);
    expect(find.textContaining('ياسر عادل'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'سعيد');
    await tester.pumpAndSettle();

    expect(find.textContaining('سعيد فتحي'), findsOneWidget);
    expect(find.textContaining('ياسر عادل'), findsNothing);
  });

  testWidgets('basin filter chips narrow the list to the selected basin',
      (final tester) async {
    await _registerRepository(const <Parcel>[
      Parcel(
        id: 'p1',
        holdingId: '',
        holderName: 'سعيد فتحي',
        basinName: 'الحوض الأول',
      ),
      Parcel(
        id: 'p2',
        holdingId: '-1',
        holderName: 'ياسر عادل',
        basinName: 'الحوض الثاني',
      ),
    ]);

    await pumpLocalizedScreen(tester, const MissingHoldingIdScreen());
    expect(find.textContaining('سعيد فتحي'), findsOneWidget);
    expect(find.textContaining('ياسر عادل'), findsOneWidget);

    await tester.tap(find.text('الحوض الأول'));
    await tester.pumpAndSettle();

    expect(find.textContaining('سعيد فتحي'), findsOneWidget);
    expect(find.textContaining('ياسر عادل'), findsNothing);
  });
}
