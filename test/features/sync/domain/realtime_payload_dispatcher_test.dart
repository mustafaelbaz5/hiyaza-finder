import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/sync/domain/parcel_change_handler.dart';
import 'package:hiyaza_finder/features/sync/domain/realtime_payload_dispatcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeParcelChangeHandler implements ParcelChangeHandler {
  final List<Parcel> changed = <Parcel>[];
  final List<String> deletedIds = <String>[];
  final List<(String, Map<String, dynamic>)> edits = <(String, Map<String, dynamic>)>[];

  @override
  void applyRemoteChange(final Parcel updated) => changed.add(updated);

  @override
  void applyRemoteDelete(final String id) => deletedIds.add(id);

  @override
  void applyRemoteEdit(final String holdingId, final Map<String, dynamic> payload) =>
      edits.add((holdingId, payload));
}

PostgresChangePayload _payload({
  required final PostgresChangeEvent eventType,
  final Map<String, dynamic> newRecord = const <String, dynamic>{},
  final Map<String, dynamic> oldRecord = const <String, dynamic>{},
}) =>
    PostgresChangePayload(
      schema: 'public',
      table: 'holdings',
      commitTimestamp: DateTime.now(),
      eventType: eventType,
      newRecord: newRecord,
      oldRecord: oldRecord,
      errors: null,
    );

void main() {
  late _FakeParcelChangeHandler handler;
  late RealtimePayloadDispatcher dispatcher;

  setUp(() {
    handler = _FakeParcelChangeHandler();
    dispatcher = RealtimePayloadDispatcher(handler);
  });

  group('handleHoldingsPayload', () {
    test('an insert/update maps the row and applies it as a remote change', () {
      dispatcher.handleHoldingsPayload(
        _payload(
          eventType: PostgresChangeEvent.update,
          newRecord: <String, dynamic>{
            'id': 'h1',
            'holding_id_number': '101',
            'holder_name': 'محمد',
          },
        ),
      );

      expect(handler.changed, hasLength(1));
      expect(handler.changed.single.id, 'h1');
      expect(handler.changed.single.holderName, 'محمد');
      expect(handler.deletedIds, isEmpty);
    });

    test('a delete removes the parcel by the old record id', () {
      dispatcher.handleHoldingsPayload(
        _payload(
          eventType: PostgresChangeEvent.delete,
          oldRecord: <String, dynamic>{'id': 'h1'},
        ),
      );

      expect(handler.deletedIds, <String>['h1']);
      expect(handler.changed, isEmpty);
    });

    test('a delete with a non-string id is a no-op', () {
      dispatcher.handleHoldingsPayload(
        _payload(
          eventType: PostgresChangeEvent.delete,
          oldRecord: <String, dynamic>{'id': 42},
        ),
      );

      expect(handler.deletedIds, isEmpty);
    });
  });

  group('handleAddedHoldingsPayload', () {
    test('an insert with no promoted_holding_id maps and applies as a change', () {
      dispatcher.handleAddedHoldingsPayload(
        _payload(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'id': 'a1',
            'holding_id_number': '-1',
            'holder_name': 'سارة',
          },
        ),
      );

      expect(handler.changed, hasLength(1));
      expect(handler.changed.single.id, 'a1');
      expect(handler.changed.single.isFieldAdded, isTrue);
      expect(handler.deletedIds, isEmpty);
    });

    test('a delete removes the parcel by the old record id', () {
      dispatcher.handleAddedHoldingsPayload(
        _payload(
          eventType: PostgresChangeEvent.delete,
          oldRecord: <String, dynamic>{'id': 'a1'},
        ),
      );

      expect(handler.deletedIds, <String>['a1']);
    });

    test(
        'a row that has just been promoted (promoted_holding_id set) is '
        'treated as a delete, not an upsert — avoids showing both the '
        'pre-promotion added_holdings row and the new holdings row as two '
        'separate people', () {
      dispatcher.handleAddedHoldingsPayload(
        _payload(
          eventType: PostgresChangeEvent.update,
          newRecord: <String, dynamic>{
            'id': 'a1',
            'promoted_holding_id': 'h1',
          },
        ),
      );

      expect(handler.deletedIds, <String>['a1']);
      expect(handler.changed, isEmpty);
    });
  });

  group('handleHoldingEditPayload', () {
    test('a valid edit payload is applied against its holding id', () {
      dispatcher.handleHoldingEditPayload(
        _payload(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'holding_id': 'h1',
            'payload': <String, dynamic>{'crop_type': 'قمح'},
          },
        ),
      );

      expect(handler.edits, hasLength(1));
      expect(handler.edits.single.$1, 'h1');
      expect(handler.edits.single.$2, <String, dynamic>{'crop_type': 'قمح'});
    });

    test('a missing holding_id is a no-op', () {
      dispatcher.handleHoldingEditPayload(
        _payload(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'payload': <String, dynamic>{'crop_type': 'قمح'},
          },
        ),
      );

      expect(handler.edits, isEmpty);
    });

    test('a non-map payload is a no-op', () {
      dispatcher.handleHoldingEditPayload(
        _payload(
          eventType: PostgresChangeEvent.insert,
          newRecord: <String, dynamic>{
            'holding_id': 'h1',
            'payload': 'not a map',
          },
        ),
      );

      expect(handler.edits, isEmpty);
    });
  });
}
