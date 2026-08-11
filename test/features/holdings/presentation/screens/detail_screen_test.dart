import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/networking/network_info.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/screens/detail_screen.dart';
import 'package:hiyaza_finder/features/sync/data/holdings_api.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_runner.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../../../support/localized_widget_test_harness.dart';

/// Regression coverage for removing the completed-parcel sort
/// (`compareParcelsForDisplay`) — a parcel keeps its original list position
/// after being marked reviewed instead of jumping to the bottom, which was
/// the root cause of Copy ID appearing to need two taps (the tapped card
/// moved out from under the user's finger on the very next rebuild).
class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<InternetConnectionStatus> get onStatusChange => const Stream.empty();
}

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
  Future<void> markCompleted({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool completed,
    required final DateTime? completedAt,
    required final String completedByUserId,
  }) async {}

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

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'a parcel keeps its original list position after being marked '
      'reviewed via Copy ID — the list is no longer re-sorted to sink '
      'reviewed parcels to the bottom', (final tester) async {
    await getIt.reset();
    getIt.registerLazySingleton<AuthRepository>(_FakeAuthRepository.new);
    getIt.registerLazySingleton<NetworkInfo>(_FakeNetworkInfo.new);
    getIt.registerLazySingleton<SyncRunner>(SyncRunner.new);
    final HoldingsRepository repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
      holdingsApi: _FakeHoldingsApi(),
    );
    const List<Parcel> parcels = <Parcel>[
      Parcel(
        id: 'p1',
        holdingId: '101',
        holderName: 'الأول',
        basinName: 'الحوض',
        cropType: 'قمح',
        feddan: 2,
        nationalId: '12345678901234',
      ),
      Parcel(
        id: 'p2',
        holdingId: '101',
        holderName: 'الثاني',
        basinName: 'الحوض',
        cropType: 'قمح',
        feddan: 2,
        nationalId: '12345678901234',
      ),
    ];
    await repository.loadParcelsForCity('city-1', parcels);
    getIt.registerLazySingleton<HoldingsRepository>(() => repository);

    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapLocalizedScreen(const DetailScreen(parcels: parcels)),
    );
    await tester.pumpAndSettle();

    // Confirm both cards render in original order before any action, using
    // the stable ValueKey(parcel.id) added to each list item.
    final Finder firstCardFinder = find.byKey(const ValueKey<String>('p1'));
    final Finder secondCardFinder = find.byKey(const ValueKey<String>('p2'));
    final double firstYBefore = tester.getTopLeft(firstCardFinder).dy;
    final double secondYBefore = tester.getTopLeft(secondCardFinder).dy;
    expect(
      firstYBefore,
      lessThan(secondYBefore),
      reason: 'p1 must render above p2 initially, matching the order '
          'parcels were passed in.',
    );

    // Tap the first card's Copy ID chip to mark it reviewed.
    final Finder firstCardIdChip = find.descendant(
      of: firstCardFinder,
      matching: find.ancestor(
        of: find.byIcon(Icons.fingerprint_rounded),
        matching: find.byType(InkWell),
      ),
    );
    await tester.tap(firstCardIdChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // p1 must still render above p2 — no jump to the bottom despite now
    // being the reviewed one.
    final double firstYAfter = tester.getTopLeft(firstCardFinder).dy;
    final double secondYAfter = tester.getTopLeft(secondCardFinder).dy;
    expect(
      firstYAfter,
      lessThan(secondYAfter),
      reason: 'a reviewed parcel must keep its original position instead of '
          'sinking to the bottom of the list.',
    );
  });
}
