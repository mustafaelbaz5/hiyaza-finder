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

class _MarkReviewedCall {
  _MarkReviewedCall({
    required this.parcelId,
    required this.isFieldAdded,
    required this.reviewed,
    required this.reviewedAt,
    required this.reviewedByUserId,
  });

  final String parcelId;
  final bool isFieldAdded;
  final bool reviewed;
  final DateTime? reviewedAt;
  final String reviewedByUserId;
}

/// A hand-written fake standing in for the real Supabase-backed
/// [HoldingsApi] — records every `markReviewed` call and can be configured
/// to throw, so tests assert against direct-call success/failure instead
/// of enqueued outbox operations.
class _FakeHoldingsApi implements HoldingsApi {
  final List<_MarkReviewedCall> markReviewedCalls = <_MarkReviewedCall>[];
  Object? markReviewedError;

  @override
  Future<({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})>
      searchRemote({required final String cityId, required final String query}) async =>
          (holdings: const <Map<String, dynamic>>[], addedHoldings: const <Map<String, dynamic>>[]);

  @override
  Future<void> markReviewed({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool reviewed,
    required final DateTime? reviewedAt,
    required final String reviewedByUserId,
  }) async {
    if (markReviewedError != null) throw markReviewedError!;
    markReviewedCalls.add(
      _MarkReviewedCall(
        parcelId: parcelId,
        isFieldAdded: isFieldAdded,
        reviewed: reviewed,
        reviewedAt: reviewedAt,
        reviewedByUserId: reviewedByUserId,
      ),
    );
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
        await repository.setParcelReviewed('missing-id', reviewed: true);
    expect(result, isNull);
    expect(holdingsApi.markReviewedCalls, isEmpty);
  });

  test('marks a holdings-origin (isFieldAdded: false) parcel reviewed locally and calls the API', () async {
    const Parcel parcel = Parcel(id: 'p-1', holdingId: '101');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    final Parcel? updated = await repository.setParcelReviewed('p-1', reviewed: true);

    expect(updated, isNotNull);
    expect(updated!.reviewed, isTrue);
    expect(updated.reviewedAt, isNotNull);
    expect(updated.reviewedBy, 'user-1');
    expect(repository.parcels.single.reviewed, isTrue);

    expect(holdingsApi.markReviewedCalls, hasLength(1));
    final _MarkReviewedCall call = holdingsApi.markReviewedCalls.single;
    expect(call.parcelId, 'p-1');
    expect(call.isFieldAdded, isFalse);
    expect(call.reviewed, isTrue);
    expect(call.reviewedAt, isNotNull);
  });

  test('marks an added_holdings-origin (isFieldAdded: true) parcel reviewed and calls the API with isFieldAdded true', () async {
    const Parcel parcel = Parcel(id: 'p-2', holdingId: '102', isFieldAdded: true);
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    await repository.setParcelReviewed('p-2', reviewed: true);

    final _MarkReviewedCall call = holdingsApi.markReviewedCalls.single;
    expect(call.isFieldAdded, isTrue);
  });

  test('finish then un-finish calls the API twice in order, final local state is reviewed: false', () async {
    const Parcel parcel = Parcel(id: 'p-3', holdingId: '103');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

    await repository.setParcelReviewed('p-3', reviewed: true);
    await repository.setParcelReviewed('p-3', reviewed: false);

    expect(holdingsApi.markReviewedCalls, hasLength(2));
    expect(holdingsApi.markReviewedCalls[0].reviewed, isTrue);
    expect(holdingsApi.markReviewedCalls[1].reviewed, isFalse);

    final Parcel finalState = repository.parcels.single;
    expect(finalState.reviewed, isFalse);
    expect(finalState.reviewedAt, isNull);
    expect(finalState.reviewedBy, isNull);
  });

  test('a failed API call leaves the local parcel unchanged and rethrows', () async {
    const Parcel parcel = Parcel(id: 'p-4', holdingId: '104');
    await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);
    holdingsApi.markReviewedError = Exception('network down');

    await expectLater(
      repository.setParcelReviewed('p-4', reviewed: true),
      throwsA(isA<Exception>()),
    );
    expect(repository.parcels.single.reviewed, isFalse);
  });

  group('applyRemoteChange', () {
    test('adopts a remote row even immediately after a local confirmed write '
        '(no more "ahead of the server" window to guard, since the local '
        'write only happens after the server already confirmed it)', () async {
      const Parcel parcel = Parcel(id: 'p-5', holdingId: '105');
      await repository.loadParcelsForCity('city-1', const <Parcel>[parcel]);

      final Parcel? updated = await repository.setParcelReviewed('p-5', reviewed: true);
      final DateTime localReviewedAt = updated!.reviewedAt!;

      // A fresh remote row confirming the same reviewed state.
      final Parcel freshRemote = parcel.copyWith(
        reviewed: true,
        reviewedAt: localReviewedAt,
        reviewedBy: 'user-1',
      );
      repository.applyRemoteChange(freshRemote);

      final Parcel afterFresh = repository.parcels.single;
      expect(afterFresh.reviewed, isTrue);
      expect(afterFresh.reviewedAt, freshRemote.reviewedAt);
    });
  });
}
