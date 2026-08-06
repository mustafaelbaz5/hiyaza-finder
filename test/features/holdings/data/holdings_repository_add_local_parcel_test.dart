import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
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

class _AddRecordCall {
  _AddRecordCall({
    required this.id,
    required this.cityId,
    required this.record,
    required this.parentHoldingId,
    required this.createdByUserId,
  });

  final String id;
  final String cityId;
  final Map<String, dynamic> record;
  final String? parentHoldingId;
  final String createdByUserId;
}

/// A hand-written fake standing in for the real Supabase-backed
/// [HoldingsApi] — records every `addRecord` call and can be configured to
/// throw, so tests assert against direct-call success/failure instead of
/// enqueued outbox operations.
class _FakeHoldingsApi implements HoldingsApi {
  final List<_AddRecordCall> addRecordCalls = <_AddRecordCall>[];
  Object? addRecordError;

  @override
  Future<({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})>
      searchRemote({required final String cityId, required final String query}) async =>
          (holdings: const <Map<String, dynamic>>[], addedHoldings: const <Map<String, dynamic>>[]);

  /// Configurable return values for [addRecord], mirroring
  /// `added_holdings.promoted_holding_id` — mimics the real
  /// `added_holdings_auto_approve` trigger returning a *fresh* promoted
  /// `holdings.id` on every insert. Empty (the default) means "not
  /// promoted", matching most test scenarios; queue one value per expected
  /// call to exercise the immediate-promotion path across multiple adds.
  final List<String?> promotedHoldingIds = <String?>[];

  @override
  Future<String?> addRecord({
    required final String id,
    required final String cityId,
    required final Map<String, dynamic> record,
    required final String? parentHoldingId,
    required final String createdByUserId,
  }) async {
    if (addRecordError != null) throw addRecordError!;
    addRecordCalls.add(
      _AddRecordCall(
        id: id,
        cityId: cityId,
        record: record,
        parentHoldingId: parentHoldingId,
        createdByUserId: createdByUserId,
      ),
    );
    return promotedHoldingIds.isEmpty ? null : promotedHoldingIds.removeAt(0);
  }

  @override
  Future<void> deleteAddedHolding(final String id) async {}

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
  Future<void> markReviewed({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool reviewed,
    required final DateTime? reviewedAt,
    required final String reviewedByUserId,
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

void main() {
  late _FakeHoldingsApi holdingsApi;
  late HoldingsRepository repository;

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<AuthRepository>(_FakeAuthRepository.new);

    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    holdingsApi = _FakeHoldingsApi();
    repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
      holdingsApi: holdingsApi,
    );
    // Simulate an active city (addLocalParcel is a no-op without one).
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('returns null and calls the API nothing when no city is active', () async {
    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    final HoldingsRepository noCityRepo = HoldingsRepository(
      editsStore: ParcelEditsStore(store: store),
      holdingsApi: holdingsApi,
    );
    final Parcel? result = await noCityRepo.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );
    expect(result, isNull);
    expect(holdingsApi.addRecordCalls, isEmpty);
  });

  test('appends the new parcel to the in-memory dataset with a fresh id', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(added, isNotNull);
    expect(added!.id, isNotEmpty);
    expect(added.sourceAddedHoldingId, added.id);
    expect(repository.parcels, hasLength(1));
    expect(repository.parcels.single.holderName, 'محمد');
  });

  test(
      'adopts the promoted holdings.id immediately when the server reports '
      'this add_holdings row was already promoted (added_holdings_auto_approve '
      'trigger) — regression test: the record must never be shown, even '
      'briefly, under its pre-promotion id, since that id gets superseded '
      'and removed as soon as the corresponding Realtime event arrives, '
      "which previously made a single new person look like it 'moved' or "
      'duplicated on screen', () async {
    holdingsApi.promotedHoldingIds.add('promoted-holdings-id');

    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(added, isNotNull);
    expect(added!.id, 'promoted-holdings-id');
    expect(added.isFieldAdded, isFalse);
    expect(added.sourceAddedHoldingId, isNotNull);
    expect(repository.parcels, hasLength(1));
    expect(repository.parcels.single.id, 'promoted-holdings-id');
    expect(repository.parcels.single.sourceAddedHoldingId, added.sourceAddedHoldingId);
  });

  test(
      'REGRESSION: two parcels added for the same new person, both '
      'immediately promoted (as the real added_holdings_auto_approve '
      'trigger does), must share the same groupKey — reproduces the '
      "'appears as two separate people in search' bug report", () async {
    // First add: brand-new person "Ahmed", no parentHoldingId yet.
    holdingsApi.promotedHoldingIds.add('ahmed-holdings-id-1');
    final Parcel? parcelA = await repository.addLocalParcel(
      const Parcel(holdingId: '-1', holderName: 'Ahmed', landNumber: '-1'),
    );
    expect(parcelA, isNotNull);

    // Second add: "add another parcel for Ahmed" — parentHoldingId is
    // Ahmed's current (already-promoted) id, exactly as
    // DetailScreen._addParcelForPerson passes `source.id` after opening
    // via a freshly re-fetched `parcelsForHolding(result.groupKey)`.
    holdingsApi.promotedHoldingIds.add('ahmed-holdings-id-2');
    final Parcel? parcelB = await repository.addLocalParcel(
      const Parcel(holdingId: '-1', holderName: 'Ahmed', landNumber: '-1'),
      parentHoldingId: parcelA!.id,
    );
    expect(parcelB, isNotNull);

    expect(
      parcelB!.groupKey,
      parcelA.groupKey,
      reason: 'Both parcels belong to the same person and must group '
          'together in search/detail, regardless of each having received '
          'its own distinct promoted holdings.id from the server.',
    );
    expect(repository.parcels, hasLength(2));
  });

  test(
      'REGRESSION: a Realtime echo of this device\'s own write '
      '(applyRemoteChange) must not clobber pendingGroupId on a sibling '
      'parcel — this is the actual mechanism behind the '
      "'appears as two separate people' report: pendingGroupId has no "
      'column in holdings/added_holdings, so any row built by '
      'holdingRowToParcel/addedHoldingRowToParcel always has it null, and '
      'applyRemoteChange previously replaced the whole Parcel object '
      'wholesale on every Realtime event for this city — including the '
      "echo of the parcel's own just-completed insert", () async {
    holdingsApi.promotedHoldingIds.add('ahmed-holdings-id-1');
    final Parcel? parcelA = await repository.addLocalParcel(
      const Parcel(holdingId: '-1', holderName: 'Ahmed', landNumber: '-1'),
    );
    holdingsApi.promotedHoldingIds.add('ahmed-holdings-id-2');
    final Parcel? parcelB = await repository.addLocalParcel(
      const Parcel(holdingId: '-1', holderName: 'Ahmed', landNumber: '-1'),
      parentHoldingId: parcelA!.id,
    );
    expect(parcelB!.groupKey, parcelA.groupKey); // sanity check, same as above

    // Simulate the Realtime channel echoing parcel B's own INSERT back —
    // exactly what holdingRowToParcel/addedHoldingRowToParcel would build
    // from the raw Postgres row: every editable/known field present, but
    // NO pendingGroupId (that column doesn't exist server-side).
    final Parcel echoedRow = Parcel(
      id: parcelB.id,
      holdingId: parcelB.holdingId,
      holderName: parcelB.holderName,
      landNumber: parcelB.landNumber,
      isFieldAdded: false,
      // pendingGroupId deliberately omitted — defaults to null, matching
      // what a real row-mapper output always looks like.
    );
    repository.applyRemoteChange(echoedRow);

    final Parcel afterEcho =
        repository.parcels.firstWhere((final Parcel p) => p.id == parcelB.id);
    expect(
      afterEcho.groupKey,
      parcelA.groupKey,
      reason: 'parcelB must remain grouped with parcelA even after its own '
          'Realtime echo arrives — the echo must not silently reset '
          'pendingGroupId to null and un-group it.',
    );
  });

  test('calls addRecord with a null parentHoldingId for a new person', () async {
    await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(holdingsApi.addRecordCalls, hasLength(1));
    final _AddRecordCall call = holdingsApi.addRecordCalls.single;
    expect(call.cityId, 'city-1');
    expect(call.parentHoldingId, isNull);
    expect(call.record['holder_name'], 'محمد');
  });

  test('calls addRecord with the given parentHoldingId for a new parcel', () async {
    await repository.addLocalParcel(
      const Parcel(holdingId: '101', holderName: 'محمد', landNumber: '-1'),
      parentHoldingId: 'existing-holding-id',
    );

    final _AddRecordCall call = holdingsApi.addRecordCalls.single;
    expect(call.parentHoldingId, 'existing-holding-id');
  });

  test(
      'sends the real holdings.id as parentHoldingId when the parent parcel '
      'is an imported (not field-added) holding', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[
      Parcel(id: 'imported-holding-id', holdingId: '229', holderName: 'محمد', isFieldAdded: false),
    ]);

    await repository.addLocalParcel(
      const Parcel(holdingId: '229', holderName: 'محمد', landNumber: '-1'),
      parentHoldingId: 'imported-holding-id',
    );

    final _AddRecordCall call = holdingsApi.addRecordCalls.single;
    expect(call.parentHoldingId, 'imported-holding-id');
  });

  test(
      'nulls out parentHoldingId when the parent parcel is field-added '
      '(added_holdings-origin) — regression test for the '
      'added_holdings_parent_holding_id_fkey violation: an added_holdings.id '
      'is never a valid holdings.id, so it must never be sent as '
      'parent_holding_id.', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[
      Parcel(id: 'added-holdings-row-id', holdingId: '229', holderName: 'محمد', isFieldAdded: true),
    ]);

    await repository.addLocalParcel(
      const Parcel(holdingId: '229', holderName: 'محمد', landNumber: '-1'),
      parentHoldingId: 'added-holdings-row-id',
    );

    final _AddRecordCall call = holdingsApi.addRecordCalls.single;
    expect(call.parentHoldingId, isNull);
  });

  test('the addRecord call id matches the new parcel\'s id (doubles as client_id)', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );
    final _AddRecordCall call = holdingsApi.addRecordCalls.single;
    expect(call.id, added!.id);
  });

  test('a failed addRecord call leaves the in-memory dataset untouched and rethrows', () async {
    holdingsApi.addRecordError = Exception('network down');

    await expectLater(
      repository.addLocalParcel(const Parcel(holdingId: '', holderName: 'محمد')),
      throwsA(isA<Exception>()),
    );
    expect(repository.parcels, isEmpty);
  });
}
