import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:hiyaza_finder/core/networking/network_info.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/sync/data/sync_outbox_impl.dart';
import 'package:hiyaza_finder/features/sync/data/sync_runner.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/repositories/sync_api.dart';
import 'package:hiyaza_finder/features/sync/presentation/cubit/sync_status_cubit.dart';

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

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<InternetConnectionStatus> get onStatusChange =>
      const Stream<InternetConnectionStatus>.empty();
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AppUser? get currentUser => const AppUser(
        id: 'user-1',
        email: 'a@b.com',
        displayName: 'A',
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

class _FakeSyncApi implements SyncApi {
  final Set<String> failingIds = <String>{};

  @override
  Future<void> pushEditHolding(
    final EditHoldingOperation operation, {
    required final String editedByUserId,
  }) async {
    if (failingIds.contains(operation.id)) {
      throw Exception('simulated failure');
    }
  }

  @override
  Future<void> pushBulkEdit(
    final BulkEditOperation operation, {
    required final String editedByUserId,
  }) async {}

  @override
  Future<void> pushAddRecord(
    final AddRecordOperation operation, {
    required final String createdByUserId,
  }) async {}
}

EditHoldingOperation _op(final String id, {final int attempts = 0}) => EditHoldingOperation(
      id: id,
      createdAt: DateTime(2026),
      attempts: attempts,
      lastAttemptAt: attempts > 0 ? DateTime(2020) : null, // long past backoff
      cityId: 'city-1',
      holdingId: 'h-$id',
      payload: const <String, dynamic>{'notes': 'x'},
    );

void main() {
  test('starts with zero pending/failed counts for an empty outbox', () async {
    final SyncOutboxImpl outbox = SyncOutboxImpl(_InMemoryKeyValueStore());
    final SyncStatusCubit cubit = SyncStatusCubit(
      queue: outbox,
      runner: SyncRunner(
        queue: outbox,
        api: _FakeSyncApi(),
        authRepository: _FakeAuthRepository(),
      ),
      networkInfo: _FakeNetworkInfo(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.pendingCount, 0);
    expect(cubit.state.failedCount, 0);
    await cubit.close();
  });

  test('reflects a permanently-failed operation in failedCount', () async {
    final SyncOutboxImpl outbox = SyncOutboxImpl(_InMemoryKeyValueStore());
    await outbox.enqueue(_op('a', attempts: syncMaxAttempts));

    final SyncStatusCubit cubit = SyncStatusCubit(
      queue: outbox,
      runner: SyncRunner(
        queue: outbox,
        api: _FakeSyncApi(),
        authRepository: _FakeAuthRepository(),
      ),
      networkInfo: _FakeNetworkInfo(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.pendingCount, 1);
    expect(cubit.state.failedCount, 1);
    expect(cubit.state.hasFailed, isTrue);
    await cubit.close();
  });

  test('retryFailed resets attempts and re-flushes, clearing failedCount on success', () async {
    final SyncOutboxImpl outbox = SyncOutboxImpl(_InMemoryKeyValueStore());
    await outbox.enqueue(_op('a', attempts: syncMaxAttempts));
    final _FakeSyncApi api = _FakeSyncApi(); // no longer failing

    final SyncStatusCubit cubit = SyncStatusCubit(
      queue: outbox,
      runner: SyncRunner(
        queue: outbox,
        api: api,
        authRepository: _FakeAuthRepository(),
      ),
      networkInfo: _FakeNetworkInfo(),
    );

    await cubit.retryFailed();

    expect(cubit.state.pendingCount, 0);
    expect(cubit.state.failedCount, 0);
    await cubit.close();
  });
}
