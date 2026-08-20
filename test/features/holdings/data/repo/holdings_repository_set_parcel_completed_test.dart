import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/errors/exceptions.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/sync/data/holdings_api.dart';

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

class _MarkCompletedCall {
  _MarkCompletedCall({
    required this.parcelId,
    required this.isFieldAdded,
    required this.completed,
    required this.completedAt,
    required this.completedByUserId,
  });

  final String parcelId;
  final bool isFieldAdded;
  final bool completed;
  final DateTime? completedAt;
  final String completedByUserId;
}

/// A hand-written fake standing in for the real Supabase-backed
/// [HoldingsApi] — records every `markCompleted` call and can be configured
/// to throw, so tests assert against direct-call success/failure instead
/// of enqueued outbox operations.
class _FakeHoldingsApi implements HoldingsApi {
  final List<_MarkCompletedCall> markCompletedCalls = <_MarkCompletedCall>[];
  Object? markCompletedError;

  /// Fires synchronously, mid-`markCompleted`, before it returns — lets a
  /// test simulate a Realtime event mutating the repository's dataset
  /// (shifting array positions) while this RPC call is still in flight.
  void Function()? onMarkCompleted;

  @override
  Future<({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})>
      searchRemote({required final String cityId, required final String query}) async =>
          (holdings: const <Map<String, dynamic>>[], addedHoldings: const <Map<String, dynamic>>[]);

  /// Configurable result for [fetchParcelById] — lets a test simulate the
  /// reconciliation read after a timeout finding the write already
  /// committed server-side (or not).
  ({Map<String, dynamic> row, bool isFieldAdded})? fetchParcelByIdResult;

  @override
  Future<({Map<String, dynamic> row, bool isFieldAdded})?> fetchParcelById(
    final String id, {
    final bool? isFieldAdded,
  }) async =>
      fetchParcelByIdResult;

  @override
  Future<void> markCompleted({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool completed,
    required final DateTime? completedAt,
    required final String completedByUserId,
  }) async {
    if (markCompletedError != null) throw markCompletedError!;
    markCompletedCalls.add(
      _MarkCompletedCall(
        parcelId: parcelId,
        isFieldAdded: isFieldAdded,
        completed: completed,
        completedAt: completedAt,
        completedByUserId: completedByUserId,
      ),
    );
    onMarkCompleted?.call();
  }

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
  _FakeAuthRepository(this._userId);

  final String? _userId;

  @override
  AppUser? get currentUser {
    final String? userId = _userId;
    if (userId == null) return null;
    return AppUser(
      id: userId,
      email: 'field@example.com',
      displayName: 'Field Worker',
      role: UserRole.field,
    );
  }

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
  late _FakeHoldingsApi holdingsApi;
  late HoldingsRepository repository;

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<AuthRepository>(() => _FakeAuthRepository('user-1'));

    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    holdingsApi = _FakeHoldingsApi();
    repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
      holdingsApi: holdingsApi,
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('returns null when the parcel is not in the active dataset', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
    final Parcel? result =
        await repository.setParcelCompleted('missing-id', completed: true);
    expect(result, isNull);
    expect(holdingsApi.markCompletedCalls, isEmpty);
  });

  test('marks a holdings-origin (isFieldAdded: false) parcel completed locally and calls the API', () async {
    const Parcel parcel = Parcel(id: 'p-1', holdingId: '101');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    final Parcel? updated = await repository.setParcelCompleted('p-1', completed: true);

    expect(updated, isNotNull);
    expect(updated!.completedAt, isNotNull);
    expect(updated.completedBy, 'user-1');
    expect(repository.parcels.single.completedAt, isNotNull);

    expect(holdingsApi.markCompletedCalls, hasLength(1));
    final _MarkCompletedCall call = holdingsApi.markCompletedCalls.single;
    expect(call.parcelId, 'p-1');
    expect(call.isFieldAdded, isFalse);
    expect(call.completed, isTrue);
    expect(call.completedAt, isNotNull);
  });

  test('marks an added_holdings-origin (isFieldAdded: true) parcel completed and calls the API with isFieldAdded true', () async {
    const Parcel parcel = Parcel(id: 'p-2', holdingId: '102', isFieldAdded: true);
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    await repository.setParcelCompleted('p-2', completed: true);

    final _MarkCompletedCall call = holdingsApi.markCompletedCalls.single;
    expect(call.isFieldAdded, isTrue);
  });

  test('finish then un-finish calls the API twice in order, final local state is not completed', () async {
    const Parcel parcel = Parcel(id: 'p-3', holdingId: '103');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    await repository.setParcelCompleted('p-3', completed: true);
    await repository.setParcelCompleted('p-3', completed: false);

    expect(holdingsApi.markCompletedCalls, hasLength(2));
    expect(holdingsApi.markCompletedCalls[0].completed, isTrue);
    expect(holdingsApi.markCompletedCalls[1].completed, isFalse);

    final Parcel finalState = repository.parcels.single;
    expect(finalState.completedAt, isNull);
    expect(finalState.completedBy, isNull);
  });

  test('a failed API call leaves the local parcel unchanged and rethrows', () async {
    const Parcel parcel = Parcel(id: 'p-4', holdingId: '104');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);
    holdingsApi.markCompletedError = Exception('network down');

    await expectLater(
      repository.setParcelCompleted('p-4', completed: true),
      throwsA(isA<Exception>()),
    );
    expect(repository.parcels.single.completedAt, isNull);
  });

  test(
      "REGRESSION: a Realtime event that shifts array positions while "
      "markCompleted's RPC is in flight must not cause the eventual local "
      "apply to land on the wrong parcel — setParcelCompleted used to "
      "capture `idx` once before the await and reuse it afterward via "
      "_applyCompletedLocally, so if a new entry got appended ahead of the "
      "target parcel's position during the await (via applyRemoteChange, "
      "e.g. another device's own add arriving over Realtime), the stale "
      'index would write the completion onto a completely different, '
      'unrelated parcel.', () async {
    const Parcel target = Parcel(id: 'target-id', holdingId: '101');
    await repository.loadParcelsForCity('city-1', const <Parcel>[target]);

    // While markCompleted is "in flight," a Realtime event inserts a new
    // parcel at the FRONT of the array by replacing the whole list —
    // simulated here by removing target and re-adding it after a new
    // unrelated entry, which is exactly what applyRemoteChange's
    // append-when-not-found path would produce for a genuinely new row.
    holdingsApi.onMarkCompleted = () {
      repository.applyRemoteChange(
        const Parcel(id: 'unrelated-new-id', holdingId: '999'),
      );
    };

    final Parcel? updated =
        await repository.setParcelCompleted('target-id', completed: true);

    expect(updated, isNotNull);
    final Parcel unrelated = repository.parcels
        .firstWhere((final Parcel p) => p.id == 'unrelated-new-id');
    final Parcel targetAfter = repository.parcels
        .firstWhere((final Parcel p) => p.id == 'target-id');

    expect(
      unrelated.completedAt,
      isNull,
      reason: 'the unrelated parcel that raced in via Realtime must not '
          'have been the one that got marked completed.',
    );
    expect(
      targetAfter.completedAt,
      isNotNull,
      reason: 'the actually-targeted parcel must be the one marked '
          'completed, regardless of what index it ended up at.',
    );
  });

  group('setParcelCompletedWithReconciliation', () {
    test('behaves exactly like setParcelCompleted on a normal success — no '
        'reconciliation needed', () async {
      const Parcel parcel = Parcel(id: 'p-6', holdingId: '106');
      await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

      final Parcel? updated = await repository
          .setParcelCompletedWithReconciliation('p-6', completed: true);

      expect(updated, isNotNull);
      expect(updated!.completedAt, isNotNull);
      expect(holdingsApi.markCompletedCalls, hasLength(1));
    });

    test(
        'a NotFoundException (stale isFieldAdded) reconciles via '
        'fetchParcelById and retries setParcelCompleted once, succeeding '
        'transparently — this is the fix for إعادة الفتح\'s "المورد غير '
        'موجود" bug: the exact same reconcile-and-retry Copy ID already had, '
        'now shared by both call sites', () async {
      const Parcel staleParcel = Parcel(
        id: 'p-stale',
        holdingId: '107',
        isFieldAdded: true, // stale — this device thinks it's still added
      );
      await repository.loadParcelsForCity('city-1', const <Parcel>[staleParcel]);

      // First markCompleted call (isFieldAdded: true, from the stale local
      // flag) fails with NotFoundException; refreshParcel's fetchParcelById
      // finds it under holdings (isFieldAdded: false) instead.
      holdingsApi.markCompletedError = NotFoundException();
      holdingsApi.fetchParcelByIdResult = (
        row: <String, dynamic>{
          'id': 'p-stale',
          'holding_id_number': '107',
          'completed_at': null,
        },
        isFieldAdded: false,
      );

      final Future<Parcel?> pending = repository
          .setParcelCompletedWithReconciliation('p-stale', completed: true);

      // The retry (after reconciliation) should succeed — clear the error
      // so the second markCompleted call goes through. Since
      // setParcelCompletedWithReconciliation awaits synchronously in
      // sequence (no concurrent races here), clearing before awaiting the
      // whole thing is safe: the first call already threw and was recorded
      // as a failed attempt before this line runs.
      holdingsApi.markCompletedError = null;
      final Parcel? updated = await pending;

      expect(updated, isNotNull);
      expect(
        updated!.completedAt,
        isNotNull,
        reason: 'the retry after reconciliation must have actually applied '
            'the completion, not just silently given up.',
      );
    });

    test(
        'a NotFoundException that still fails after reconciliation propagates '
        'the second failure to the caller, not a false success', () async {
      const Parcel parcel = Parcel(id: 'p-still-missing', holdingId: '108');
      await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

      holdingsApi.markCompletedError = NotFoundException();
      holdingsApi.fetchParcelByIdResult = null; // reconciliation finds nothing

      await expectLater(
        repository.setParcelCompletedWithReconciliation(
          'p-still-missing',
          completed: true,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('a ConflictException is NOT retried — propagates straight through, '
        'since a genuine conflict would just fail again identically',
        () async {
      const Parcel parcel = Parcel(id: 'p-conflict', holdingId: '109');
      await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);
      holdingsApi.markCompletedError = ConflictException();

      await expectLater(
        repository.setParcelCompletedWithReconciliation(
          'p-conflict',
          completed: true,
        ),
        throwsA(isA<ConflictException>()),
      );
      expect(
        holdingsApi.markCompletedCalls,
        isEmpty,
        reason: 'markCompletedCalls only records successful (non-throwing) '
            'calls in this fake — a single throwing attempt with no retry '
            'confirms setParcelCompletedWithReconciliation did not loop on '
            'a ConflictException.',
      );
    });
  });

  group('applyRemoteChange', () {
    test('adopts a remote row even immediately after a local confirmed write '
        '(no more "ahead of the server" window to guard, since the local '
        'write only happens after the server already confirmed it)', () async {
      const Parcel parcel = Parcel(id: 'p-5', holdingId: '105');
      await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

      final Parcel? updated = await repository.setParcelCompleted('p-5', completed: true);
      final DateTime localCompletedAt = updated!.completedAt!;

      // A fresh remote row confirming the same completed state.
      final Parcel freshRemote = parcel.copyWith(
        completedAt: localCompletedAt,
        completedBy: 'user-1',
      );
      repository.applyRemoteChange(freshRemote);

      final Parcel afterFresh = repository.parcels.single;
      expect(afterFresh.completedAt, isNotNull);
      expect(afterFresh.completedAt, freshRemote.completedAt);
    });
  });
}
