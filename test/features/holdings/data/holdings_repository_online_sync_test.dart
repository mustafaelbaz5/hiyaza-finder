import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/networking/network_info.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/data/services/add_parcel_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/bulk_edit_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/complete_parcel_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/delete_parcel_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/edit_parcel_sync_handler.dart';
import 'package:hiyaza_finder/features/holdings/data/services/parcel_sync_service.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/bulk_editable_field.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/sync/data/holdings_api.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_runner.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// `REFACTOR_ROADMAP.md` Phase 19: when a `_syncRunner` IS configured (the
/// real app's shape) but the device is online, every write must call
/// straight into the network and await it — never apply optimistically or
/// enqueue. This is the actual behavior change this phase delivers;
/// `holdings_repository_outbox_test.dart` covers the offline fallback,
/// `holdings_repository_add_local_parcel_test.dart`/others cover the
/// no-`_syncRunner`-configured path. This file is the missing third case:
/// `_syncRunner` present AND online.
class _OnlineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<InternetConnectionStatus> get onStatusChange => const Stream.empty();
}

class _RecordingHoldingsApi implements HoldingsApi {
  final List<String> addRecordCalls = <String>[];
  final List<String> deleteCalls = <String>[];
  final List<String> editCalls = <String>[];
  final List<String> markCompletedCalls = <String>[];
  Object? errorFor;

  /// Fires synchronously, mid-`editHolding`, before it returns — lets a
  /// test simulate a Realtime event mutating the repository's dataset
  /// while this call is still in flight.
  void Function()? onEditHolding;

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
    onEditHolding?.call();
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
      networkInfo: _OnlineNetworkInfo(),
    );
    await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('addLocalParcel (online)', () {
    test('calls the network directly — never enqueues on SyncRunner', () async {
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );

      expect(added, isNotNull);
      expect(holdingsApi.addRecordCalls, hasLength(1));
      expect(syncRunner.operations, isEmpty);
    });

    test('a failed network call throws and leaves the dataset untouched', () async {
      holdingsApi.errorFor = 'add';

      await expectLater(
        repository.addLocalParcel(const Parcel(holdingId: '', holderName: 'محمد')),
        throwsA(isA<Exception>()),
      );
      expect(repository.parcels, isEmpty);
      expect(syncRunner.operations, isEmpty);
    });
  });

  group('setParcelCompleted (online)', () {
    test('calls markCompleted directly and awaits it before returning', () async {
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );

      final Parcel? updated =
          await repository.setParcelCompleted(added!.id, completed: true);

      expect(updated!.completedAt, isNotNull);
      expect(holdingsApi.markCompletedCalls, contains(added.id));
      expect(syncRunner.operations, isEmpty);
    });

    test(
      'a failed network call throws and leaves completedAt unset locally',
      () async {
        final Parcel? added = await repository.addLocalParcel(
          const Parcel(holdingId: '', holderName: 'محمد'),
        );
        holdingsApi.errorFor = 'completed';

        await expectLater(
          repository.setParcelCompleted(added!.id, completed: true),
          throwsA(isA<Exception>()),
        );
        expect(repository.parcels.single.completedAt, isNull);
        expect(syncRunner.operations, isEmpty);
      },
    );
  });

  group('updateParcel (online)', () {
    test('calls editHolding directly before applying the edit locally', () async {
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );

      await repository.updateParcel(added!.copyWith(holderName: 'أحمد'));

      expect(holdingsApi.editCalls, contains(added.id));
      expect(repository.parcels.single.holderName, 'أحمد');
      expect(syncRunner.operations, isEmpty);
    });

    test('a failed network call throws and leaves the parcel unedited', () async {
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );
      holdingsApi.errorFor = 'edit';

      await expectLater(
        repository.updateParcel(added!.copyWith(holderName: 'أحمد')),
        throwsA(isA<Exception>()),
      );
      expect(repository.parcels.single.holderName, 'محمد');
      expect(syncRunner.operations, isEmpty);
    });

    test(
        'REGRESSION: a Realtime event that shifts array positions while '
        'editHolding is in flight must not cause the eventual local apply '
        'to land on the wrong parcel', () async {
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );

      holdingsApi.onEditHolding = () {
        repository.applyRemoteChange(
          const Parcel(id: 'unrelated-new-id', holdingId: '999'),
        );
      };

      await repository.updateParcel(added!.copyWith(holderName: 'أحمد'));

      final Parcel unrelated = repository.parcels
          .firstWhere((final Parcel p) => p.id == 'unrelated-new-id');
      final Parcel editedAfter =
          repository.parcels.firstWhere((final Parcel p) => p.id == added.id);

      expect(
        unrelated.holderName,
        isNull,
        reason: 'the unrelated parcel that raced in via Realtime must not '
            'have received the edit.',
      );
      expect(editedAfter.holderName, 'أحمد');
    });
  });

  group('deleteLocalParcel (online)', () {
    test('calls deleteAddedHolding directly before removing locally', () async {
      final Parcel? added = await repository.addLocalParcel(
        const Parcel(holdingId: '', holderName: 'محمد'),
      );

      final bool deleted = await repository.deleteLocalParcel(added!.id);

      expect(deleted, isTrue);
      expect(holdingsApi.deleteCalls, contains(added.id));
      expect(repository.parcels, isEmpty);
      expect(syncRunner.operations, isEmpty);
    });
  });

  group('bulkApplyField (online)', () {
    test('reports the real per-row outcome, not a queued count', () async {
      await repository.addLocalParcel(
        const Parcel(holdingId: '1', holderName: 'محمد', cropType: 'قمح'),
      );

      final outcome = await repository.bulkApplyField(
        field: BulkEditableField.cropType,
        value: 'ذرة',
      );

      expect(outcome.succeeded, 1);
      expect(outcome.failed, 0);
      expect(repository.parcels.single.cropType, 'ذرة');
      expect(syncRunner.operations, isEmpty);
    });
  });
}
