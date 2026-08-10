import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/auth/domain/entities/app_user.dart';
import 'package:hiyaza_finder/features/auth/domain/repositories/auth_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/holdings_repository.dart';
import 'package:hiyaza_finder/features/holdings/data/repository/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/presentation/screens/add_record_screen.dart';
import 'package:hiyaza_finder/features/sync/data/holdings_api.dart';

import '../../../../support/localized_widget_test_harness.dart';

/// `add_record_screen.dart` was trimmed down to a fixed field list per the
/// user's request (رقم الحيازة, اسم الحائز, اسم الحوض, رقم الأرض, المساحة,
/// نوع الزرع, الملاحظات, الرقم القومي [new-person only], وراثة/مفوض toggles)
/// — عدد القطع/نوع الائتمان/نوع الاستخدام/مراحل النمو are no longer shown.
/// اسم المالك now only appears once مفوض is toggled on, rather than always.
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

class _FakeHoldingsApi implements HoldingsApi {
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

  @override
  Future<void> markCompleted({
    required final String parcelId,
    required final bool isFieldAdded,
    required final bool completed,
    required final DateTime? completedAt,
    required final String completedByUserId,
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

Future<void> _registerRepository() async {
  await getIt.reset();
  getIt.registerLazySingleton<AuthRepository>(_FakeAuthRepository.new);
  final HoldingsRepository repository = HoldingsRepository(
    editsStore: ParcelEditsStore(store: _InMemoryKeyValueStore()),
    holdingsApi: _FakeHoldingsApi(),
  );
  await repository.loadParcelsForCity('city-1', const <Parcel>[]);
  getIt.registerLazySingleton<HoldingsRepository>(() => repository);
}

void main() {
  setUpAll(initLocalizedWidgetTestHarness);

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
      'اسم المالك is hidden until مفوض is toggled on, for both new-person '
      'and new-parcel-for-existing-person flows', (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(holdingId: ''),
      ),
    );

    expect(find.text('اسم المالك'), findsNothing);

    final Finder delegateSwitch = find.byType(Switch).last;
    await tester.tap(delegateSwitch);
    await tester.pumpAndSettle();

    expect(find.text('اسم المالك'), findsOneWidget);

    await tester.tap(delegateSwitch);
    await tester.pumpAndSettle();

    expect(find.text('اسم المالك'), findsNothing);
  });

  testWidgets('عدد القطع/نوع الائتمان/نوع الاستخدام/مراحل النمو are no '
      'longer shown on the trimmed form', (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(holdingId: ''),
      ),
    );

    expect(find.text('نوع الائتمان'), findsNothing);
    expect(find.text('نوع الاستخدام'), findsNothing);
    expect(find.text('مراحل النمو'), findsNothing);
  });

  testWidgets('الرقم القومي only shows for the new-person flow '
      '(parentHoldingId == null)', (final tester) async {
    await _registerRepository();

    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(holdingId: ''),
      ),
    );
    expect(find.text('الرقم القومي'), findsOneWidget);

    await _registerRepository();
    await pumpLocalizedScreen(
      tester,
      const AddRecordScreen(
        initialParcel: Parcel(id: 'p1', holdingId: '', holderName: 'أحمد'),
        parentHoldingId: 'p1',
      ),
    );
    expect(find.text('الرقم القومي'), findsNothing);
  });
}
