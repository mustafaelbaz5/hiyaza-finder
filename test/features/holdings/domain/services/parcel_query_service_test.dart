import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/domain/services/border_name_index.dart';
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

  group('pending (not-yet-numbered) new people don\'t collide', () {
    // Two different brand-new people, both with the "-" placeholder
    // رقم الحيازة — a raw-holdingId comparison would incorrectly treat
    // them as the same holding.
    final List<Parcel> pendingParcels = <Parcel>[
      const Parcel(id: 'new-1', holdingId: '-', holderName: 'شخص أول', basinName: 'البشيط'),
      const Parcel(id: 'new-2', holdingId: '-', holderName: 'شخص ثاني', basinName: 'البشيط'),
    ];

    test('basinHoldingCounts counts them as two separate holdings', () {
      final Map<String, int> counts = service.basinHoldingCounts(pendingParcels);
      expect(counts['البشيط'], 2);
    });

    test('parcelsForHolding scoped to one groupKey returns only that person', () {
      final String firstKey = pendingParcels[0].groupKey;
      final List<Parcel> result = service.parcelsForHolding(pendingParcels, firstKey);
      expect(result, hasLength(1));
      expect(result.single.holderName, 'شخص أول');
    });
  });

  group('findByBorderText', () {
    final BorderNameIndex index = BorderNameIndex.build(parcels);

    test('matches a حائز name exactly and returns null for non-matches/non-person text', () {
      expect(service.findByBorderText(index, 'محمد على')!.holdingId, '101');
      expect(service.findByBorderText(index, 'محمد'), isNull); // no substring match
      expect(service.findByBorderText(index, null), isNull);
      expect(service.findByBorderText(index, 'طريق'), isNull);
    });

    test('ambiguous name resolves to the holding with the most parcels', () {
      final List<Parcel> ambiguous = <Parcel>[
        const Parcel(id: 'a1', holdingId: '201', holderName: 'علي حسن'),
        const Parcel(id: 'a2', holdingId: '202', holderName: 'علي حسن'),
        const Parcel(id: 'a3', holdingId: '202', holderName: 'علي حسن'),
      ];
      final BorderNameIndex ambiguousIndex = BorderNameIndex.build(ambiguous);
      expect(service.findByBorderText(ambiguousIndex, 'علي حسن')!.holdingId, '202');
    });
  });
}
