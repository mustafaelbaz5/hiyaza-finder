import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/jazla/data/local/jazla_search_service.dart';

void main() {
  const JazlaSearchService service = JazlaSearchService();

  const Parcel free = Parcel(id: 'p1', holdingId: '10', holderName: 'محمد أحمد');
  const Parcel locked = Parcel(id: 'p2', holdingId: '11', holderName: 'محمد علي');

  test('returns empty results for a blank query', () {
    final results = service.search(<Parcel>[free, locked], '   ', <String, String>{});
    expect(results, isEmpty);
  });

  test('marks a parcel present in jazlaNameByParcelId as locked', () {
    final results = service.search(
      <Parcel>[free, locked],
      'محمد',
      <String, String>{'p2': 'جزلة الري'},
    );

    final ParcelSearchResult freeResult =
        results.firstWhere((final r) => r.parcel.id == 'p1');
    final ParcelSearchResult lockedResult =
        results.firstWhere((final r) => r.parcel.id == 'p2');

    expect(freeResult.isLocked, isFalse);
    expect(freeResult.jazlaName, isNull);
    expect(lockedResult.isLocked, isTrue);
    expect(lockedResult.jazlaName, 'جزلة الري');
  });

  test('free results sort ahead of locked results regardless of score', () {
    // "محمد أحمد" scores higher (exact full-name match) than "محمد علي" for
    // the query "محمد أحمد" — locking the higher-scoring one should still
    // push it below the free, lower-scoring one.
    final results = service.search(
      <Parcel>[free, locked],
      'محمد',
      <String, String>{'p1': 'جزلة الري'},
    );

    expect(results.first.parcel.id, 'p2');
    expect(results.first.isLocked, isFalse);
    expect(results.last.parcel.id, 'p1');
    expect(results.last.isLocked, isTrue);
  });

  test('routes an all-digit query through exact holding-number matching', () {
    final results = service.search(<Parcel>[free, locked], '10', <String, String>{});
    expect(results, hasLength(1));
    expect(results.single.parcel.id, 'p1');
  });

  test('routes a parcel-id-shaped query through parcel id matching', () {
    const Parcel withUuid = Parcel(id: 'abcdef1234567890', holdingId: '99');
    final results = service.search(
      <Parcel>[withUuid],
      'abcdef12',
      <String, String>{},
    );
    expect(results, hasLength(1));
    expect(results.single.parcel.id, 'abcdef1234567890');
  });
}
