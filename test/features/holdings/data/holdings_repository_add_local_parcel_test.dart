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
  Future<void> addRecord({
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
    expect(repository.parcels, hasLength(1));
    expect(repository.parcels.single.holderName, 'محمد');
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
