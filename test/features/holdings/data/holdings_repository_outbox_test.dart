import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/networking/network_info.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/data/services/add_parcel_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/bulk_edit_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/delete_parcel_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/edit_parcel_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/complete_parcel_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/parcel_sync_service.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/bulk_editable_field.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/sync/data/holdings_api.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_runner.dart';

/// Records every network call the outbox handlers make once
/// `SyncRunner.flush()` actually executes an operation — separate from the
/// `HoldingsRepository` mutation itself, which happens synchronously before
/// any of these run (`REFACTOR_ROADMAP.md` Phase 9 #9's optimistic-write
/// contract).
class _RecordingHoldingsApi implements HoldingsApi {
  final List<String> addRecordCalls = <String>[];
  final List<String> deleteCalls = <String>[];
  final List<String> editCalls = <String>[];
  final List<String> markCompletedCalls = <String>[];
  Object? errorFor;

  @override
  Future<String?> addRecord({
    required final String id,
    required final String cityId,
    required final Map<String, dynamic> record,
    required final String? parentHoldingId,
    required final String createdByUserId,
  }) async {
    if (errorFor == 'add') throw Exception('network down');
    addRecordCalls.add(id);
    return null;
  }

  @override
  Future<void> deleteAddedHolding(final String id) async {
    if (errorFor == 'delete') throw Exception('network down');
    deleteCalls.add(id);
  }

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
  }) async {
    if (errorFor == 'edit') throw Exception('network down');
    editCalls.add(holdingId);
  }

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
  }) async {
    if (errorFor == 'completed') throw Exception('network down');
    markCompletedCalls.add(parcelId);
  }

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
}

/// This entire test file exercises the *offline* outbox path
/// (`REFACTOR_ROADMAP.md` Phase 19) — every write here is expected to
/// apply optimistically and enqueue, never await the network directly.
/// Without an explicit offline signal, `HoldingsRepository._isOnline`
/// defaults to `true` (matching the real app's normal, connected case) and
/// these writes would instead take the online/awaited path, silently
/// testing the wrong thing.
class _OfflineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<InternetConnectionStatus> get onStatusChange => const Stream.empty();
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
  late _RecordingHoldingsApi holdingsApi;
  late SyncRunner syncRunner;
  late HoldingsRepository repository;

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<AuthRepository>(_FakeAuthRepository.new);

    holdingsApi = _RecordingHoldingsApi();
    final ParcelSyncService syncService = ParcelSyncService(holdingsApi: holdingsApi);
    syncRunner = SyncRunner()
      ..registerHandler(AddParcelOperation, AddParcelSyncHandler(syncService))
      ..registerHandler(DeleteParcelOperation, DeleteParcelSyncHandler(holdingsApi))
      ..registerHandler(EditParcelOperation, EditParcelSyncHandler(syncService))
      ..registerHandler(CompleteParcelOperation, CompleteParcelSyncHandler(holdingsApi))
      ..registerHandler(BulkEditOperation, BulkEditSyncHandler(holdingsApi));

    repository = HoldingsRepository(
      editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
      holdingsApi: holdingsApi,
      syncService: syncService,
      syncRunner: syncRunner,
      networkInfo: _OfflineNetworkInfo(),
    );
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('addLocalParcel (outbox)', () {
    test('mutates the local dataset before any network call is made', () async {
      // No await on flush — the assertion runs synchronously right after
      // addLocalParcel returns, proving the write didn't wait on the
      // network.
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );

      expect(added, isNotNull);
      expect(repository.parcels, hasLength(1));
      expect(repository.parcels.single.holderName, 'محمد');
    });

    test('enqueues an AddParcelOperation that flush() later executes', () async {
      await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );
      // addLocalParcel's own fire-and-forget flush may already be in
      // flight; awaiting flush() again is idempotent (SyncRunner guards
      // re-entrant flushes) and guarantees completion before asserting.
      await syncRunner.flush();

      expect(holdingsApi.addRecordCalls, hasLength(1));
    });

    test('a failed network call does not undo the optimistic local write', () async {
      holdingsApi.errorFor = 'add';
      await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );
      await syncRunner.flush();

      // Still present locally — the outbox model's whole point is that a
      // background failure doesn't retroactively undo what the user
      // already saw succeed.
      expect(repository.parcels, hasLength(1));
      expect(syncRunner.operations, hasLength(1));
      expect(syncRunner.operations.single.lastError, isNotNull);
    });
  });

  group('deleteLocalParcel (outbox)', () {
    test('removes locally before any network call, enqueues a delete', () async {
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );
      await syncRunner.flush();
      holdingsApi.addRecordCalls.clear();

      final bool deleted = await repository.deleteLocalParcel(added!.id);
      expect(deleted, isTrue);
      expect(repository.parcels, isEmpty);

      await syncRunner.flush();
      expect(holdingsApi.deleteCalls, hasLength(1));
    });
  });

  group('setParcelCompleted (outbox)', () {
    test('applies completed state locally before any network call', () async {
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );
      await syncRunner.flush();

      final Parcel? updated =
          await repository.setParcelCompleted(added!.id, completed: true);

      expect(updated!.completedAt, isNotNull);
      expect(repository.parcels.single.completedAt, isNotNull);
      expect(repository.parcels.single.completedBy, 'user-1');
    });

    test('enqueues and eventually calls markCompleted', () async {
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );
      await syncRunner.flush();

      await repository.setParcelCompleted(added!.id, completed: true);
      await syncRunner.flush();

      expect(holdingsApi.markCompletedCalls, contains(added.id));
    });
  });

  group('bulkApplyField (outbox)', () {
    test('applies changes locally and reports them as queued', () async {
      await repository.addLocalParcel(
        const Parcel(holdingId: '1', holderName: 'محمد', cropType: 'قمح'),
      );
      await syncRunner.flush();

      final outcome = await repository.bulkApplyField(
        field: BulkEditableField.cropType,
        value: 'ذرة',
      );

      expect(outcome.succeeded, 1);
      expect(outcome.failed, 0);
      expect(repository.parcels.single.cropType, 'ذرة');
    });
  });
}
