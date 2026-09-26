import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/core/storage/key_value_store.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/local_edit_tracker.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/local_added_parcels_store.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/parcel_completion_store.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/parcel_edits_store.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/parcel_id_overrides_store.dart';
import 'package:hiyaza_finder/features/parcel_review/data/model/bulk_edit_outcome.dart';
import 'package:hiyaza_finder/features/parcel_review/data/model/bulk_editable_field.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/repo/parcel_catalog_repository.dart';

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
  late ParcelCatalogRepository repository;

  final List<Parcel> seed = List<Parcel>.generate(
    5,
    (final int i) => Parcel(id: 'p$i', holdingId: '10$i', basinName: 'الحوض أ'),
  );

  setUp(() async {
    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
    repository = ParcelCatalogRepository(
      editsStore: ParcelEditsStore(store: store),
      editTracker: LocalEditTracker(store: store),
      addedParcelsStore: LocalAddedParcelsStore(store: store),
      completionStore: ParcelCompletionStore(store: store),
      idOverridesStore: ParcelIdOverridesStore(store: store),
    );
    await repository.loadParcelsForCity('city-1', seed);
  });

  test('parcelIds scopes the bulk edit to only the given ids', () async {
    final BulkEditOutcome outcome = await repository.bulkApplyField(
      field: BulkEditableField.cropType,
      value: 'قمح',
      parcelIds: <String>{'p0', 'p2'},
    );

    expect(outcome.succeeded, 2);
    final Map<String, Parcel> byId = <String, Parcel>{
      for (final Parcel p in repository.parcels) p.id: p,
    };
    expect(byId['p0']!.cropType, 'قمح');
    expect(byId['p2']!.cropType, 'قمح');
    expect(byId['p1']!.cropType, isNull);
  });

  test('onProgress is called and reaches 1.0 by the end', () async {
    final List<double> progressUpdates = <double>[];

    await repository.bulkApplyField(
      field: BulkEditableField.cropType,
      value: 'ذرة',
      onProgress: progressUpdates.add,
    );

    expect(progressUpdates, isNotEmpty);
    expect(progressUpdates.last, 1.0);
  });

  test('every in-scope parcel is marked edited after a bulk apply', () async {
    await repository.bulkApplyField(
      field: BulkEditableField.cropType,
      value: 'أرز',
      parcelIds: <String>{'p0', 'p1', 'p2'},
    );

    expect(repository.isParcelEdited('p0'), isTrue);
    expect(repository.isParcelEdited('p1'), isTrue);
    expect(repository.isParcelEdited('p2'), isTrue);
    expect(repository.isParcelEdited('p3'), isFalse);
  });

  test('an empty parcelIds set changes nothing', () async {
    final BulkEditOutcome outcome = await repository.bulkApplyField(
      field: BulkEditableField.cropType,
      value: 'قمح',
      parcelIds: const <String>{},
    );

    expect(outcome.succeeded, 0);
    expect(outcome.failed, 0);
  });
}
