import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/model/basin_progress.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/holdings/data/local/border_name_index.dart';
import 'package:hiyaza_finder/features/holdings/data/local/parcel_query_service.dart';
import 'package:hiyaza_finder/features/holdings/data/local/holding_search_service.dart';

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

  group('basinSummaries', () {
    test('counts a holding as completed only when every one of its parcels is', () {
      final List<Parcel> mixed = <Parcel>[
        Parcel(
          id: '1',
          holdingId: '101',
          basinName: 'الباشا',
          completedAt: DateTime(2026, 1, 1),
        ),
        const Parcel(id: '2', holdingId: '102', basinName: 'الباشا'), // not completed
        const Parcel(id: '3', holdingId: '103', basinName: 'البحيره'),
      ];

      final List<BasinProgress> summaries = service.basinSummaries(mixed);
      final BasinProgress basha =
          summaries.firstWhere((final BasinProgress b) => b.basinName == 'الباشا');
      expect(basha.totalCount, 2);
      expect(basha.completedCount, 1);
      expect(basha.isFullyCompleted, isFalse);

      final BasinProgress bahira =
          summaries.firstWhere((final BasinProgress b) => b.basinName == 'البحيره');
      expect(bahira.isNotStarted, isTrue);
    });

    test('a multi-parcel holding only counts as completed once every parcel is', () {
      final List<Parcel> multiParcelHolding = <Parcel>[
        Parcel(
          id: '1',
          holdingId: '101',
          basinName: 'الباشا',
          completedAt: DateTime(2026, 1, 1),
        ),
        const Parcel(id: '2', holdingId: '101', basinName: 'الباشا'), // same holding, not done
      ];

      final BasinProgress basha = service.basinSummaries(multiParcelHolding).single;
      expect(basha.totalCount, 1); // one holding
      expect(basha.completedCount, 0); // not every parcel is completed
    });

    test('is sorted by basin name', () {
      final List<Parcel> unordered = <Parcel>[
        const Parcel(id: '1', holdingId: '1', basinName: 'ب'),
        const Parcel(id: '2', holdingId: '2', basinName: 'أ'),
      ];
      final List<BasinProgress> summaries = service.basinSummaries(unordered);
      expect(summaries.map((final BasinProgress b) => b.basinName), <String>['أ', 'ب']);
    });
  });

  group('adjacentHoldingGroupKey', () {
    final List<Parcel> basinParcels = <Parcel>[
      const Parcel(id: 'p1', holdingId: '1', basinName: 'الباشا'),
      const Parcel(id: 'p2', holdingId: '3', basinName: 'الباشا'),
      const Parcel(id: 'p3', holdingId: '2', basinName: 'الباشا'),
    ];

    test('next/previous follow رقم الحيازة ascending order, not list order', () {
      expect(
        service.adjacentHoldingGroupKey(basinParcels, 'الباشا', '1', next: true),
        '2',
      );
      expect(
        service.adjacentHoldingGroupKey(basinParcels, 'الباشا', '2', next: true),
        '3',
      );
      expect(
        service.adjacentHoldingGroupKey(basinParcels, 'الباشا', '2', next: false),
        '1',
      );
    });

    test('returns null at either end', () {
      expect(
        service.adjacentHoldingGroupKey(basinParcels, 'الباشا', '1', next: false),
        isNull,
      );
      expect(
        service.adjacentHoldingGroupKey(basinParcels, 'الباشا', '3', next: true),
        isNull,
      );
    });

    test('returns null for a groupKey not in the given basin', () {
      expect(
        service.adjacentHoldingGroupKey(basinParcels, 'حوض آخر', '1', next: true),
        isNull,
      );
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
