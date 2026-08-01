import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/sync/data/sync_outbox_impl.dart';
import 'package:hiyaza_finder/features/sync/data/sync_runner.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/repositories/sync_api.dart';

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

class _FakeAuthRepository implements AuthRepository {
  AppUser? user = const AppUser(
    id: 'user-1',
    email: 'a@b.com',
    displayName: 'A',
    role: UserRole.field,
  );

  @override
  AppUser? get currentUser => user;

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

class _FakeSyncApi implements SyncApi {
  final List<String> pushedEditIds = <String>[];
  final List<String> pushedAddIds = <String>[];
  final Set<String> failingIds = <String>{};

  @override
  Future<void> pushEditHolding(
    final EditHoldingOperation operation, {
    required final String editedByUserId,
  }) async {
    if (failingIds.contains(operation.id)) {
      throw Exception('simulated network failure');
    }
    pushedEditIds.add(operation.id);
  }

  @override
  Future<void> pushBulkEdit(
    final BulkEditOperation operation, {
    required final String editedByUserId,
  }) async {
    if (failingIds.contains(operation.id)) {
      throw Exception('simulated network failure');
    }
    pushedEditIds.add(operation.id);
  }

  @override
  Future<void> pushAddRecord(
    final AddRecordOperation operation, {
    required final String createdByUserId,
  }) async {
    if (failingIds.contains(operation.id)) {
      throw Exception('simulated network failure');
    }
    pushedAddIds.add(operation.id);
  }
}

EditHoldingOperation _op(final String id, {final int attempts = 0}) => EditHoldingOperation(
      id: id,
      createdAt: DateTime(2026),
      attempts: attempts,
      cityId: 'city-1',
      holdingId: 'h-$id',
      payload: const <String, dynamic>{'notes': 'x'},
    );

void main() {
  late SyncOutboxImpl outbox;
  late _FakeSyncApi api;
  late _FakeAuthRepository authRepository;
  late SyncRunner runner;

  setUp(() {
    outbox = SyncOutboxImpl(_InMemoryKeyValueStore());
    api = _FakeSyncApi();
    authRepository = _FakeAuthRepository();
    runner = SyncRunner(queue: outbox, api: api, authRepository: authRepository);
  });

  test('a successful push removes the operation from the outbox', () async {
    await outbox.enqueue(_op('a'));
    await runner.flush();

    expect(api.pushedEditIds, <String>['a']);
    expect(await outbox.pending(), isEmpty);
  });

  test('a failed push increments attempts and keeps the operation queued', () async {
    api.failingIds.add('a');
    await outbox.enqueue(_op('a'));
    await runner.flush();

    final List<SyncOperation> pending = await outbox.pending();
    expect(pending, hasLength(1));
    expect(pending.single.attempts, 1);
    expect(pending.single.lastAttemptAt, isNotNull);
  });

  test('an operation at syncMaxAttempts is skipped, not retried forever', () async {
    await outbox.enqueue(_op('a', attempts: syncMaxAttempts));
    await runner.flush();

    expect(api.pushedEditIds, isEmpty);
    // Still parked in the queue, just not retried.
    expect(await outbox.pending(), hasLength(1));
  });

  test('a just-failed operation is skipped again immediately (backoff)', () async {
    api.failingIds.add('a');
    await outbox.enqueue(_op('a'));
    await runner.flush(); // attempts -> 1, lastAttemptAt set to "now"
    api.failingIds.clear(); // would succeed now, if attempted

    await runner.flush(); // but backoff hasn't elapsed yet

    expect(api.pushedEditIds, isEmpty);
    expect((await outbox.pending()).single.attempts, 1);
  });

  test('flush does nothing when signed out', () async {
    authRepository.user = null;
    await outbox.enqueue(_op('a'));
    await runner.flush();

    expect(api.pushedEditIds, isEmpty);
    expect(await outbox.pending(), hasLength(1));
  });

  test('multiple pending operations are pushed in order', () async {
    await outbox.enqueue(_op('a'));
    await outbox.enqueue(_op('b'));
    await runner.flush();

    expect(api.pushedEditIds, <String>['a', 'b']);
    expect(await outbox.pending(), isEmpty);
  });
}
