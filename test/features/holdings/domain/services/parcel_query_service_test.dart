import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/domain/services/parcel_query_service.dart';
import 'package:hiyaza_finder/features/holdings/logic/services/holding_search_service.dart';

void main() {
  const ParcelQueryService service = ParcelQueryService();

  final List<Parcel> parcels = <Parcel>[
    const Parcel(id: '1', holdingId: '101', holderName: 'محمد علي', basinName: 'البشيط'),
    const Parcel(id: '2', holdingId: '101', holderName: 'محمد علي', basinName: 'البشيط'),
    const Parcel(id: '3', holdingId: '102', holderName: 'احمد فريد', basinName: 'السواخ'),
    const Parcel(id: '4', holdingId: '103', holderName: 'سعيد محمود'),
  ];

  test('search scoped to a basin only considers that basin\'s parcels', () {
    final List<SearchResult> results = service.search(
      parcels,
      'محمد',
      basin: 'السواخ',
    );
    expect(results, isEmpty);
  });

  test('search across the whole dataset finds a match', () {
    final List<SearchResult> results = service.search(parcels, 'محمد');
    expect(results, isNotEmpty);
    expect(results.first.holdingId, '101');
  });

  test('availableBasins returns distinct, sorted, non-empty basin names', () {
    expect(service.availableBasins(parcels), <String>['البشيط', 'السواخ']);
  });

  test('basinHoldingCounts counts distinct holdings per basin', () {
    final Map<String, int> counts = service.basinHoldingCounts(parcels);
    expect(counts['البشيط'], 1); // two parcels, same holding id
    expect(counts['السواخ'], 1);
    expect(counts.containsKey(null), isFalse);
  });

  test('parcelsForHolding returns every parcel sharing that holding id', () {
    final List<Parcel> result = service.parcelsForHolding(parcels, '101');
    expect(result, hasLength(2));
    expect(result.every((final Parcel p) => p.holdingId == '101'), isTrue);
  });
}
