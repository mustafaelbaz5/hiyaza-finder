import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/services/complete_parcel_sync_handler.dart';
import 'package:hiyaza_finder/features/sync/data/holdings_api.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';

/// A hand-written fake standing in for the real Supabase-backed
/// [HoldingsApi] — records `markCompleted` calls and lets tests script
/// [fetchParcelById]'s return value, so the reconciliation pre-check added
/// to [CompleteParcelSyncHandler] can be exercised without a network.
class _FakeHoldingsApi implements HoldingsApi {
  ({Map<String, dynamic> row, bool isFieldAdded})? fetchParcelByIdResult;
  int markCompletedCallCount = 0;
  Object? markCompletedError;

  /// The `isFieldAdded` value [fetchParcelById] was actually called with —
  /// asserted against directly, since the whole point of the reconciliation
  /// pre-check is to NOT trust `op.isFieldAdded` (it may be the stale value
  /// causing the ambiguity being reconciled) and check both tables instead.
  bool? lastFetchParcelByIdArg;
  bool fetchParcelByIdWasCalled = false;

  /// The `isFieldAdded` value [markCompleted] was actually called with.
  bool? lastMarkCompletedIsFieldAdded;

  @override
  Future<({Map<String, dynamic> row, bool isFieldAdded})?> fetchParcelById(
    final String id, {
    final bool? isFieldAdded,
  }) async {
    fetchParcelByIdWasCalled = true;
    lastFetchParcelByIdArg = isFieldAdded;
    return fetchParcelByIdResult;
  }

  @override
  Future<void> markCompleted({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool completed,
    required final DateTime? completedAt,
    required final String completedByUserId,
  }) async {
    markCompletedCallCount++;
    lastMarkCompletedIsFieldAdded = isFieldAdded;
    if (markCompletedError != null) throw markCompletedError!;
  }

  @override
  Future<({List<Map<String, dynamic>> holdings, List<Map<String, dynamic>> addedHoldings})>
      searchRemote({required final String cityId, required final String query}) async =>
          (holdings: const <Map<String, dynamic>>[], addedHoldings: const <Map<String, dynamic>>[]);

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

CompleteParcelOperation _op({required final bool completed}) =>
    CompleteParcelOperation(
      operationId: 'op1',
      createdAt: DateTime(2026),
      parcelId: 'p1',
      isFieldAdded: false,
      completed: completed,
      completedAt: completed ? DateTime(2026) : null,
      completedByUserId: 'user-1',
    );

void main() {
  group('CompleteParcelSyncHandler — reconciliation pre-check', () {
    test(
        'skips markCompleted (treats as success) when the server already '
        'has completed_at set and the operation wants completed=true — the '
        '"already done by someone else" case', () async {
      final _FakeHoldingsApi api = _FakeHoldingsApi()
        ..fetchParcelByIdResult = (
          row: <String, dynamic>{'completed_at': '2026-01-01T00:00:00.000Z'},
          isFieldAdded: false,
        );
      final CompleteParcelSyncHandler handler = CompleteParcelSyncHandler(api);

      await handler.execute(_op(completed: true));

      expect(api.markCompletedCallCount, 0);
    });

    test(
        'skips markCompleted when the server already has completed_at null '
        'and the operation wants completed=false', () async {
      final _FakeHoldingsApi api = _FakeHoldingsApi()
        ..fetchParcelByIdResult = (
          row: <String, dynamic>{'completed_at': null},
          isFieldAdded: false,
        );
      final CompleteParcelSyncHandler handler = CompleteParcelSyncHandler(api);

      await handler.execute(_op(completed: false));

      expect(api.markCompletedCallCount, 0);
    });

    test(
        'calls markCompleted when the server state does NOT already match '
        'the desired outcome — a genuine pending write', () async {
      final _FakeHoldingsApi api = _FakeHoldingsApi()
        ..fetchParcelByIdResult = (
          row: <String, dynamic>{'completed_at': null},
          isFieldAdded: false,
        );
      final CompleteParcelSyncHandler handler = CompleteParcelSyncHandler(api);

      await handler.execute(_op(completed: true));

      expect(api.markCompletedCallCount, 1);
    });

    test(
        'calls markCompleted when the reconciliation read finds nothing '
        '(still uncertain) — falls through to the normal write path',
        () async {
      final _FakeHoldingsApi api = _FakeHoldingsApi()
        ..fetchParcelByIdResult = null;
      final CompleteParcelSyncHandler handler = CompleteParcelSyncHandler(api);

      await handler.execute(_op(completed: true));

      expect(api.markCompletedCallCount, 1);
    });

    test('propagates a genuine markCompleted failure when the pre-check '
        "doesn't resolve it", () async {
      final _FakeHoldingsApi api = _FakeHoldingsApi()
        ..fetchParcelByIdResult = (
          row: <String, dynamic>{'completed_at': null},
          isFieldAdded: false,
        )
        ..markCompletedError = Exception('boom');
      final CompleteParcelSyncHandler handler = CompleteParcelSyncHandler(api);

      await expectLater(
        () => handler.execute(_op(completed: true)),
        throwsA(isA<Exception>()),
      );
    });

    test(
        'the reconciliation read checks BOTH tables (passes isFieldAdded: '
        'null), never trusting op.isFieldAdded — that cached flag may '
        'itself be the stale value causing "record not found" (the parcel '
        'was promoted between added_holdings/holdings after this operation '
        'was queued), mirroring HoldingsRepository.refreshParcel\'s '
        'identical reasoning', () async {
      final _FakeHoldingsApi api = _FakeHoldingsApi()
        ..fetchParcelByIdResult = (
          row: <String, dynamic>{'completed_at': null},
          isFieldAdded: false,
        );
      final CompleteParcelSyncHandler handler = CompleteParcelSyncHandler(api);

      // op.isFieldAdded is true, but the pre-check must not pass that
      // through — it must ask fetchParcelById to search both tables.
      await handler.execute(
        CompleteParcelOperation(
          operationId: 'op1',
          createdAt: DateTime(2026),
          parcelId: 'p1',
          isFieldAdded: true,
          completed: true,
          completedAt: DateTime(2026),
          completedByUserId: 'user-1',
        ),
      );

      expect(api.fetchParcelByIdWasCalled, isTrue);
      expect(api.lastFetchParcelByIdArg, isNull);
    });

    test(
        'when the stale isFieldAdded caused the parcel to actually live in '
        'the OTHER table, markCompleted is called with the corrected, '
        'resolved isFieldAdded from the reconciliation read — not the '
        'stale op.isFieldAdded — so the write targets the right table',
        () async {
      final _FakeHoldingsApi api = _FakeHoldingsApi()
        ..fetchParcelByIdResult = (
          // Found in added_holdings, contradicting op.isFieldAdded=false
          // below, and not yet completed — so this must proceed to a real
          // write, using the RESOLVED isFieldAdded (true).
          row: <String, dynamic>{'completed_at': null},
          isFieldAdded: true,
        );
      final CompleteParcelSyncHandler handler = CompleteParcelSyncHandler(api);

      await handler.execute(
        CompleteParcelOperation(
          operationId: 'op1',
          createdAt: DateTime(2026),
          parcelId: 'p1',
          isFieldAdded: false, // stale — the real location is added_holdings
          completed: true,
          completedAt: DateTime(2026),
          completedByUserId: 'user-1',
        ),
      );

      expect(api.markCompletedCallCount, 1);
      expect(api.lastMarkCompletedIsFieldAdded, isTrue);
    });

    test(
        'falls back to the operation\'s own isFieldAdded for the write when '
        'the reconciliation read finds nothing at all', () async {
      final _FakeHoldingsApi api = _FakeHoldingsApi()..fetchParcelByIdResult = null;
      final CompleteParcelSyncHandler handler = CompleteParcelSyncHandler(api);

      await handler.execute(
        CompleteParcelOperation(
          operationId: 'op1',
          createdAt: DateTime(2026),
          parcelId: 'p1',
          isFieldAdded: true,
          completed: true,
          completedAt: DateTime(2026),
          completedByUserId: 'user-1',
        ),
      );

      expect(api.markCompletedCallCount, 1);
      expect(api.lastMarkCompletedIsFieldAdded, isTrue);
    });
  });
}
