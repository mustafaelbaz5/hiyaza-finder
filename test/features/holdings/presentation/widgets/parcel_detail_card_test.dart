import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/errors/exceptions.dart' as app_exceptions;
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/parcel_detail_card.dart';
import 'package:hiyaza_finder/features/sync/data/holdings_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the real translation file straight off disk instead of through
/// `rootBundle` — recreating [EasyLocalization] more than once in the same
/// test process (one `_wrap` call per test) makes the mocked
/// `flutter/assets` channel hang on the second+ load, so this sidesteps
/// it entirely. Two easy_localization/flutter_test pitfalls to avoid
/// here: an already-completed `SynchronousFuture` breaks `Future.wait`'s
/// bookkeeping inside easy_localization's loader-merge step (silently
/// yields empty translations), while genuinely `async` real file I/O
/// never resolves under `pump()`'s fake-async clock without
/// `tester.runAsync()`. Reading synchronously but returning it via
/// `Future.microtask` sidesteps both: it's a real (non-completed)
/// `Future`, and a microtask is exactly what the fake-async pump drives.
class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(final String path, final Locale locale) {
    return Future.microtask(() {
      final File file = File('$path/${locale.languageCode}.json');
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });
  }
}

Widget _wrap(final Widget child) {
  return EasyLocalization(
    supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
    path: 'assets/lang',
    startLocale: const Locale('ar'),
    fallbackLocale: const Locale('ar'),
    assetLoader: const _FileAssetLoader(),
    child: Builder(
      builder: (final BuildContext context) => ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (final BuildContext context, final Widget? _) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
}

Future<void> _pump(final WidgetTester tester, final Widget child) async {
  await tester.pumpWidget(_wrap(child));
  await tester.pumpAndSettle();
}

/// A no-op-by-default [HoldingsApi] fake for the [_copyId]/[onCompleted]
/// regression test below — only `markCompleted` needs real behavior.
class _FakeHoldingsApi implements HoldingsApi {
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

  /// Set by a test to make [markCompleted] throw instead of succeeding —
  /// used to simulate a timed-out `mark_parcel_completed` RPC call.
  Object? markCompletedError;

  /// How many of the next [markCompleted] calls should throw
  /// [markCompletedError] before calls start succeeding — lets a test
  /// simulate the NotFoundException-then-retry-succeeds sequence.
  int markCompletedErrorCount = 1 << 30;

  int markCompletedCallCount = 0;

  @override
  Future<void> markCompleted({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool completed,
    required final DateTime? completedAt,
    required final String completedByUserId,
  }) async {
    markCompletedCallCount++;
    if (markCompletedError != null &&
        markCompletedCallCount <= markCompletedErrorCount) {
      throw markCompletedError!;
    }
  }

  @override
  Future<({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})>
      searchRemote({required final String cityId, required final String query}) async =>
          (holdings: const <Map<String, dynamic>>[], addedHoldings: const <Map<String, dynamic>>[]);

  /// Configurable result for the post-timeout reconciliation read.
  ({Map<String, dynamic> row, bool isFieldAdded})? fetchParcelByIdResult;

  @override
  Future<({Map<String, dynamic> row, bool isFieldAdded})?> fetchParcelById(
    final String id, {
    final bool? isFieldAdded,
  }) async =>
      fetchParcelByIdResult;
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

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EasyLocalization.ensureInitialized();
    // Explicit clipboard mock — `Clipboard.setData` inside `_copyId` hangs
    // without one in some environments (no default handler is guaranteed),
    // silently stalling the whole Copy ID flow before it ever reaches
    // `setParcelCompleted`.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (final MethodCall call) async {
        if (call.method == 'Clipboard.setData') return null;
        if (call.method == 'HapticFeedback.vibrate') return null;
        return null;
      },
    );
  });

  const Parcel parcel = Parcel(
    id: 'p1',
    holdingId: '101',
    holderName: 'محمد علي',
    basinName: 'البشيط',
  );

  testWidgets('renders the holding id and holder name', (final tester) async {
    await _pump(
      tester,
      ParcelDetailCard(parcel: parcel, onFieldChanged: (final _) {}),
    );

    expect(find.text('101'), findsOneWidget);
    // Appears twice: اسم الحائز, and اسم المالك falls back to it when unset.
    expect(find.text('محمد علي'), findsNWidgets(2));
  });

  testWidgets(
    'shows the pending-number placeholder when holdingId is blank',
    (final tester) async {
      const Parcel newPersonParcel = Parcel(
        id: 'p2',
        holdingId: '',
        holderName: 'شخص جديد',
      );
      await _pump(
        tester,
        ParcelDetailCard(
          parcel: newPersonParcel,
          onFieldChanged: (final _) {},
        ),
      );

      expect(find.text('101'), findsNothing);
      expect(find.textContaining('بدون رقم'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a per-field "معدلة" badge only on fields that changed from the original',
    (final tester) async {
      // No originalParcel supplied at all — nothing should ever show as
      // modified.
      await _pump(
        tester,
        ParcelDetailCard(parcel: parcel, onFieldChanged: (final _) {}),
      );
      expect(find.text('تم التعديل'), findsNothing);

      // holderName differs from the original; every other field matches —
      // exactly one badge should appear, not one per field on the card.
      const Parcel original = Parcel(
        id: 'p1',
        holdingId: '101',
        holderName: 'شخص آخر',
        basinName: 'البشيط',
      );
      await _pump(
        tester,
        ParcelDetailCard(
          parcel: parcel,
          originalParcel: original,
          onFieldChanged: (final _) {},
        ),
      );
    expect(find.text('تم التعديل'), findsOneWidget);
  },
  );

  testWidgets(
    'shows the added badge for promoted app-created parcels even when isFieldAdded is false',
    (final tester) async {
      const Parcel promotedAddedParcel = Parcel(
        id: 'p3',
        holdingId: '101',
        holderName: 'شخص مضاف',
        basinName: 'البشيت',
        sourceAddedHoldingId: 'added-1',
        isFieldAdded: false,
      );

      await _pump(
        tester,
        ParcelDetailCard(
          parcel: promotedAddedParcel,
          onFieldChanged: (final _) {},
        ),
      );

      // The standalone top-row "مضافة من التطبيق" StatusBadge chip was
      // removed as a duplicate of the fuller added-badge banner below it
      // (`REFACTOR_ROADMAP.md` Phase 11 §12) — assert against the banner's
      // own label text instead.
      expect(find.text('مضافة من التطبيق'), findsOneWidget);
    },
  );

  testWidgets('tapping the اسم المالك pencil opens the edit dialog', (
    final tester,
  ) async {
    await _pump(
      tester,
      ParcelDetailCard(parcel: parcel, onFieldChanged: (final _) {}),
    );

    final Finder editIcon = find.descendant(
      of: find.byType(ParcelDetailCard),
      matching: find.byIcon(Icons.edit_rounded),
    );
    expect(editIcon, findsWidgets);

    await tester.tap(editIcon.first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
  });

  group('Copy ID / review (REFACTOR_ROADMAP.md Phase 20)', () {
    setUp(() async {
      await getIt.reset();
      getIt.registerLazySingleton<AuthRepository>(_FakeAuthRepository.new);
      final HoldingsRepository repository = HoldingsRepository(
        editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
        holdingsApi: _FakeHoldingsApi(),
      );
      // No `syncRunner`/`networkInfo` configured — exercises the
      // synchronous await-then-mutate path (same as "no outbox" / online),
      // matching how `setParcelCompleted` behaves in production once
      // server-confirmed.
      await repository.loadParcelsForCity('city-1', const <Parcel>[
        Parcel(
          id: 'p-review',
          holdingId: '202',
          holderName: 'محمد علي',
          basinName: 'البشيط',
          nationalId: '12345678901234',
          cropType: 'قمح',
        ),
      ]);
      getIt.registerLazySingleton<HoldingsRepository>(() => repository);
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets(
      'tapping Copy ID fires onCompleted with the confirmed parcel, not onFieldChanged',
      (final tester) async {
        const Parcel reviewParcel = Parcel(
          id: 'p-review',
          holdingId: '202',
          holderName: 'محمد علي',
          basinName: 'البشيط',
          nationalId: '12345678901234',
          cropType: 'قمح',
          feddan: 2,
        );

        Parcel? completedResult;
        bool fieldChangedCalled = false;

        await _pump(
          tester,
          ParcelDetailCard(
            parcel: reviewParcel,
            onFieldChanged: (final _) => fieldChangedCalled = true,
            onCompleted: (final updated) => completedResult = updated,
          ),
        );

        final Finder idChip = find.ancestor(
          of: find.byIcon(Icons.fingerprint_rounded),
          matching: find.byType(InkWell),
        );
        expect(idChip, findsOneWidget);

        await tester.tap(idChip);
        await tester.pumpAndSettle();

        expect(
          completedResult,
          isNotNull,
          reason: 'onCompleted must fire once setParcelCompleted is '
              'server-confirmed — the whole point of Phase 20 is that this '
              "path no longer depends on onFieldChanged/updateParcel's "
              'unrelated edit-overlay write.',
        );
        expect(completedResult!.completedAt, isNotNull);
        expect(
          fieldChangedCalled,
          isFalse,
          reason: 'onFieldChanged (routed to DetailScreen._updateField in '
              'production) must never be invoked by the review action — '
              'that was the actual bug: a redundant, unrelated write whose '
              'failure could mask an already-successful review.',
        );
        expect(find.text('تم نسخ المعرّف وتحديد الحيازة كمُراجعة'), findsOneWidget);
      },
    );

    testWidgets(
      'falls back to onFieldChanged when onCompleted is not provided',
      (final tester) async {
        const Parcel reviewParcel = Parcel(
          id: 'p-review',
          holdingId: '202',
          holderName: 'محمد علي',
          basinName: 'البشيط',
          nationalId: '12345678901234',
          cropType: 'قمح',
          feddan: 2,
        );

        Parcel? fieldChangedResult;

        await _pump(
          tester,
          ParcelDetailCard(
            parcel: reviewParcel,
            onFieldChanged: (final updated) => fieldChangedResult = updated,
          ),
        );

        final Finder idChip = find.ancestor(
          of: find.byIcon(Icons.fingerprint_rounded),
          matching: find.byType(InkWell),
        );
        await tester.tap(idChip);
        await tester.pumpAndSettle();

        expect(fieldChangedResult, isNotNull);
        expect(fieldChangedResult!.completedAt, isNotNull);
      },
    );

    testWidgets(
      'onReviewBusyChanged reports true then false around the Copy ID '
      'write — lets DetailScreen fold this into the same _busyParcelIds '
      'tracking used for Reopen/Delete, so a same-parcel Reopen tap while '
      'Copy ID is still in flight can be blocked',
      (final tester) async {
        const Parcel reviewParcel = Parcel(
          id: 'p-review',
          holdingId: '202',
          holderName: 'محمد علي',
          basinName: 'البشيط',
          nationalId: '12345678901234',
          cropType: 'قمح',
          feddan: 2,
        );

        final List<bool> busyEvents = <bool>[];

        await _pump(
          tester,
          ParcelDetailCard(
            parcel: reviewParcel,
            onFieldChanged: (final _) {},
            onReviewBusyChanged: busyEvents.add,
          ),
        );

        final Finder idChip = find.ancestor(
          of: find.byIcon(Icons.fingerprint_rounded),
          matching: find.byType(InkWell),
        );
        await tester.tap(idChip);
        await tester.pumpAndSettle();

        expect(busyEvents, <bool>[true, false]);
      },
    );
  });

  group('Copy ID timeout reconciliation (REFACTOR_ROADMAP.md Phase 25)', () {
    const Parcel reviewParcel = Parcel(
      id: 'p-review-timeout',
      holdingId: '788',
      holderName: 'محمد علي',
      basinName: 'البشيط',
      nationalId: '12345678901234',
      cropType: 'قمح',
      feddan: 2,
    );

    late _FakeHoldingsApi holdingsApi;

    setUp(() async {
      await getIt.reset();
      getIt.registerLazySingleton<AuthRepository>(_FakeAuthRepository.new);
      holdingsApi = _FakeHoldingsApi()
        ..markCompletedError = app_exceptions.TimeoutException();
      final HoldingsRepository repository = HoldingsRepository(
        editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
        holdingsApi: holdingsApi,
      );
      await repository.loadParcelsForCity('city-1', const <Parcel>[reviewParcel]);
      getIt.registerLazySingleton<HoldingsRepository>(() => repository);
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets(
      'a timeout that turns out to have actually succeeded reconciles to '
      "reviewed, via onCompleted, instead of leaving the user stuck on a "
      "plain error with no idea whether their tap worked",
      (final tester) async {
        holdingsApi.fetchParcelByIdResult = (
          row: <String, dynamic>{
            'id': reviewParcel.id,
            'holding_id_number': reviewParcel.holdingId,
            'holder_name': reviewParcel.holderName,
            'completed_at': DateTime.now().toIso8601String(),
            'completed_by': 'user-1',
          },
          isFieldAdded: false,
        );

        Parcel? completedResult;

        await _pump(
          tester,
          ParcelDetailCard(
            parcel: reviewParcel,
            onFieldChanged: (final _) {},
            onCompleted: (final updated) => completedResult = updated,
          ),
        );

        final Finder idChip = find.ancestor(
          of: find.byIcon(Icons.fingerprint_rounded),
          matching: find.byType(InkWell),
        );
        await tester.tap(idChip);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'تم نسخ المعرّف. انتهت مهلة الاتصال، لكن التحقق أكّد أن المراجعة تمت بنجاح',
          ),
          findsOneWidget,
          reason: 'must show the confirmed-after-timeout message, not a '
              'plain failure, once reconciliation finds the write actually '
              'succeeded.',
        );
        expect(
          completedResult,
          isNotNull,
          reason: 'the card must reflect the reconciled reviewed state via '
              'onCompleted, same as a normal successful review.',
        );
        expect(completedResult!.completedAt, isNotNull);
      },
    );

    testWidgets(
      'a timeout that genuinely did not go through shows the still-uncertain '
      'message, not a false success',
      (final tester) async {
        holdingsApi.fetchParcelByIdResult = null;

        Parcel? completedResult;

        await _pump(
          tester,
          ParcelDetailCard(
            parcel: reviewParcel,
            onFieldChanged: (final _) {},
            onCompleted: (final updated) => completedResult = updated,
          ),
        );

        final Finder idChip = find.ancestor(
          of: find.byIcon(Icons.fingerprint_rounded),
          matching: find.byType(InkWell),
        );
        await tester.tap(idChip);
        await tester.pumpAndSettle();

        expect(
          find.text(
            'تم نسخ المعرّف، لكن تعذّر التأكد من حالة المراجعة بسبب مشكلة في الاتصال — تحقق من الحالة لاحقًا',
          ),
          findsOneWidget,
        );
        expect(
          completedResult,
          isNull,
          reason: 'must never claim the parcel is reviewed when '
              'reconciliation could not confirm it.',
        );
      },
    );
  });

  group('Copy ID stale isFieldAdded reconciliation (REFACTOR_ROADMAP.md Phase 25 follow-up)', () {
    // Reproduces the real device log: a field-added parcel this device
    // still believes is unpromoted/local-only (`sourceAddedHoldingId` null
    // — the same shape a brand-new, not-yet-synced local parcel has) but
    // which the server has, in fact, already promoted into `holdings`.
    // `HoldingsRepository.setParcelCompleted`'s `isCurrentlyInAddedHoldings`
    // reads `true` from this stale local state (correctly, per its own
    // documented "null means still unsynced" rule — it just doesn't know
    // this parcel was actually already synced by another path), sends
    // `isFieldAdded: true`, and the RPC reports `found: false` for a row
    // that actually exists — just in `holdings`, not `added_holdings`.
    // holdingId is a real number (not the "-1" pending placeholder) —
    // REFACTOR_ROADMAP.md Phase 25's later requirement that a new
    // person/parcel must have a real هيazة number before it can even be
    // saved means a genuinely-promoted parcel reaching this reconciliation
    // path always has one; this fixture matches that, so the test exercises
    // the reconciliation/retry logic specifically, not the separate
    // required-fields gate.
    const Parcel staleParcel = Parcel(
      id: 'p-stale-field-added',
      holdingId: '788',
      holderName: 'Ahmed',
      basinName: 'البشيط',
      nationalId: '12345678901234',
      cropType: 'قمح',
      landNumber: '-1',
      isFieldAdded: true,
      feddan: 2,
    );

    late _FakeHoldingsApi holdingsApi;

    setUp(() async {
      await getIt.reset();
      getIt.registerLazySingleton<AuthRepository>(_FakeAuthRepository.new);
      holdingsApi = _FakeHoldingsApi()
        ..markCompletedError = app_exceptions.NotFoundException()
        ..markCompletedErrorCount = 1;
      final HoldingsRepository repository = HoldingsRepository(
        editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
        holdingsApi: holdingsApi,
      );
      await repository.loadParcelsForCity('city-1', const <Parcel>[staleParcel]);
      getIt.registerLazySingleton<HoldingsRepository>(() => repository);
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets(
      'a NotFoundException from a stale isFieldAdded reconciles the local '
      'flag and retries once, completing transparently without the user '
      'having to tap again',
      (final tester) async {
        // The reconciliation read finds the row under the OTHER table
        // (isFieldAdded: false) — this is what corrects the stale flag.
        holdingsApi.fetchParcelByIdResult = (
          row: <String, dynamic>{
            'id': staleParcel.id,
            'holding_id_number': staleParcel.holdingId,
            'holder_name': staleParcel.holderName,
          },
          isFieldAdded: false,
        );

        Parcel? completedResult;

        await _pump(
          tester,
          ParcelDetailCard(
            parcel: staleParcel,
            onFieldChanged: (final _) {},
            onCompleted: (final updated) => completedResult = updated,
          ),
        );

        final Finder idChip = find.ancestor(
          of: find.byIcon(Icons.fingerprint_rounded),
          matching: find.byType(InkWell),
        );
        await tester.tap(idChip);
        await tester.pumpAndSettle();

        expect(
          holdingsApi.markCompletedCallCount,
          2,
          reason: 'must retry markCompleted once after reconciling the '
              'stale isFieldAdded flag.',
        );
        expect(
          find.text('تم نسخ المعرّف وتحديد الحيازة كمُراجعة'),
          findsOneWidget,
          reason: 'the retry succeeding should show the normal success '
              'message, same as a first-try success.',
        );
        expect(completedResult, isNotNull);
        expect(completedResult!.completedAt, isNotNull);
      },
    );
  });

  group('delete/reopen loading state (REFACTOR_ROADMAP.md Phase 21)', () {
    testWidgets(
      'isDeleting shows a spinner instead of the delete icon and disables it',
      (final tester) async {
        const Parcel deletableParcel = Parcel(
          id: 'p-del',
          holdingId: '303',
          holderName: 'محمد علي',
          basinName: 'البشيط',
          sourceAddedHoldingId: 'added-1',
        );

        bool deleteConfirmedCalled = false;

        // A CircularProgressIndicator is indeterminate — it never settles,
        // so pumpAndSettle (used by the shared `_pump` helper) times out.
        // Two explicit pumps are enough to build the tree and animate one
        // frame.
        await tester.pumpWidget(
          _wrap(
            ParcelDetailCard(
              parcel: deletableParcel,
              onFieldChanged: (final _) {},
              onDelete: () => deleteConfirmedCalled = true,
              isDeleting: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        expect(
          find.descendant(
            of: find.byType(IconButton),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        final IconButton deleteButton = tester.widget<IconButton>(
          find.byType(IconButton).first,
        );
        expect(deleteButton.onPressed, isNull);

        // Tapping a disabled IconButton is a no-op — confirms the loading
        // state actually blocks re-entrant taps, not just visually.
        await tester.tap(find.byType(IconButton).first, warnIfMissed: false);
        await tester.pump();
        expect(deleteConfirmedCalled, isFalse);

        // CircularProgressIndicator's implicit animation ticker leaves a
        // pending timer that fails the test framework's teardown invariant
        // check unless the animating tree is torn down before the test ends.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'isReopening shows a spinner instead of the reopen icon and disables it',
      (final tester) async {
        final Parcel reviewedParcel = Parcel(
          id: 'p-reopen',
          holdingId: '404',
          holderName: 'محمد علي',
          basinName: 'البشيط',
          completedAt: DateTime(2026, 8, 10),
        );

        bool reopenCalled = false;

        await tester.pumpWidget(
          _wrap(
            ParcelDetailCard(
              parcel: reviewedParcel,
              onFieldChanged: (final _) {},
              onReopen: () => reopenCalled = true,
              isReopening: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
        expect(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        final FilledButton reopenButton =
            tester.widget<FilledButton>(find.byType(FilledButton));
        expect(reopenButton.onPressed, isNull);
        expect(reopenCalled, isFalse);

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  });
}
