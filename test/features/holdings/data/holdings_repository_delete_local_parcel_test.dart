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

/// A hand-written fake standing in for the real Supabase-backed
/// [HoldingsApi] — records every `deleteAddedHolding` call and can be
/// configured to throw, so tests assert against direct-call success/
/// failure instead of outbox side effects.
class _FakeHoldingsApi implements HoldingsApi {
  final List<String> deletedIds = <String>[];
  Object? deleteError;
  final List<String?> promotedHoldingIds = <String?>[];

  @override
  Future<({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})>
      searchRemote({required final String cityId, required final String query}) async =>
          (holdings: const <Map<String, dynamic>>[], addedHoldings: const <Map<String, dynamic>>[]);

  @override
  Future<void> deleteAddedHolding(final String id) async {
    if (deleteError != null) throw deleteError!;
    deletedIds.add(id);
  }

  @override
  Future<String?> addRecord({
    required final String id,
    required final String cityId,
    required final Map<String, dynamic> record,
    required final String? parentHoldingId,
    required final String createdByUserId,
  }) async =>
      promotedHoldingIds.isEmpty ? null : promotedHoldingIds.removeAt(0);

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

    holdingsApi = _FakeHoldingsApi();
    repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
      holdingsApi: holdingsApi,
    );
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('a field-added parcel is deleted from the server and locally', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(await repository.deleteLocalParcel(added!.id), isTrue);
    expect(repository.parcels, isEmpty);
    expect(holdingsApi.deletedIds, <String>[added.sourceAddedHoldingId!]);
  });

  test('a promoted field-added parcel still deletes using its original added row id', () async {
    holdingsApi.promotedHoldingIds.add('promoted-holding-id');
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );

    expect(added, isNotNull);
    expect(added!.isFieldAdded, isFalse);
    expect(added.sourceAddedHoldingId, isNotNull);

    expect(await repository.deleteLocalParcel(added.id), isTrue);
    expect(repository.parcels, isEmpty);
    expect(holdingsApi.deletedIds, <String>[added.sourceAddedHoldingId!]);
  });

  test('an imported (not field-added) holding cannot be deleted', () async {
    await repository.loadParcelsForCity('city-1', const <Parcel>[
      Parcel(id: 'imported-1', holdingId: '101', isFieldAdded: false),
    ]);

    expect(await repository.deleteLocalParcel('imported-1'), isFalse);
    expect(repository.parcels, hasLength(1));
    expect(holdingsApi.deletedIds, isEmpty);
  });

  test('a missing id is a no-op and returns false', () async {
    expect(await repository.deleteLocalParcel('missing-id'), isFalse);
    expect(holdingsApi.deletedIds, isEmpty);
  });

  test('a failed server delete leaves the local dataset untouched and rethrows', () async {
    final Parcel? added = await repository.addLocalParcel(
      const Parcel(holdingId: '', holderName: 'محمد'),
    );
    holdingsApi.deleteError = Exception('network down');

    await expectLater(
      repository.deleteLocalParcel(added!.id),
      throwsA(isA<Exception>()),
    );
    expect(repository.parcels, hasLength(1));
  });
}
