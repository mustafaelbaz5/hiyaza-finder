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
    test('matches a حائز name exactly (after Arabic normalization)', () {
      final Parcel? match = service.findByBorderText(parcels, 'محمد على');
      expect(match, isNotNull);
      expect(match!.holdingId, '101');
    });

    test('matches a مالك name when the حائز differs', () {
      final List<Parcel> withOwner = <Parcel>[
        const Parcel(
          id: '5',
          holdingId: '104',
          holderName: 'ورثة فلان',
          ownerName: 'خالد سعيد',
        ),
      ];
      final Parcel? match = service.findByBorderText(withOwner, 'خالد سعيد');
      expect(match, isNotNull);
      expect(match!.holdingId, '104');
    });

    test('does not match on partial/substring overlap', () {
      // 'محمد' alone should not match 'محمد علي' — exact match only, unlike
      // HoldingSearchService's fuzzy substring search, since a wrong guess
      // here means navigating to the wrong person's land.
      final Parcel? match = service.findByBorderText(parcels, 'محمد');
      expect(match, isNull);
    });

    test('returns null for blank or placeholder border text', () {
      expect(service.findByBorderText(parcels, null), isNull);
      expect(service.findByBorderText(parcels, ''), isNull);
      expect(service.findByBorderText(parcels, '   '), isNull);
      expect(service.findByBorderText(parcels, '-'), isNull);
    });

    test('returns null for non-person boundary text (طريق/مصرف/ترعة/...)', () {
      expect(service.findByBorderText(parcels, 'طريق'), isNull);
      expect(service.findByBorderText(parcels, 'مصرف عام'), isNull);
      expect(service.findByBorderText(parcels, 'ترعة الشيخ'), isNull);
    });

    test('returns null when no holder/owner matches', () {
      final Parcel? match = service.findByBorderText(parcels, 'شخص غير موجود');
      expect(match, isNull);
    });
  });
}
