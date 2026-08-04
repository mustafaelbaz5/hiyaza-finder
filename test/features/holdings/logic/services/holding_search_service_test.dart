import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/logic/services/holding_search_service.dart';

Parcel _parcel(final String holdingId, final String holderName) => Parcel(
      holdingId: holdingId,
      holderName: holderName,
    );

void main() {
  const HoldingSearchService service = HoldingSearchService();

  final List<Parcel> parcels = [
    _parcel('001117', 'محمد أحمد علي'),
    _parcel('001117', 'محمد أحمد علي'), // 2nd parcel, same holding
    _parcel('002200', 'علي حسن محمود'),
    _parcel('003300', 'سارة محمد'),
  ];

  group('numeric queries', () {
    test('exact match scores 100', () {
      final results = service.search(parcels, '001117');
      expect(results.first.holdingId, '001117');
      expect(results.first.score, 100);
      expect(results.first.parcelCount, 2);
    });

    test('partial digits (prefix or substring) do not match', () {
      expect(service.search(parcels, '0011'), isEmpty);
      expect(service.search(parcels, '117'), isEmpty);
    });

    test('no digit match returns empty', () {
      final results = service.search(parcels, '999999');
      expect(results, isEmpty);
    });
  });

  group('text queries', () {
    test('matches when the full name starts with the query', () {
      final results = service.search(parcels, 'محمد احمد');
      expect(results.map((final r) => r.holdingId), contains('001117'));
    });

    test('matches when an inner word starts with the query', () {
      final results = service.search(parcels, 'احمد');
      expect(results.map((final r) => r.holdingId), contains('001117'));
    });

    test('normalizes hamza variants and ة/ه before matching', () {
      final results = service.search(parcels, 'محمد أحمد'); // hamza kept
      expect(results.map((final r) => r.holdingId), contains('001117'));
    });

    test('a query that only appears mid-word matches as tier 2 (contains)', () {
      // 'مد' is inside "محمد" but not at a word-start or full-name-start —
      // still returned (fixes ".contains()" dropping relevant results
      // entirely), just ranked below any tier-1 (starts-with) match.
      final results = service.search(parcels, 'مد');
      final match = results.firstWhere((final r) => r.holdingId == '001117');
      expect(match.score, 40);
    });

    test('tier 1 (starts with) ranks above tier 2 (contains)', () {
      final mixed = [
        _parcel('t1', 'مديحة علي'), // starts with 'مد' -> tier 1
        _parcel('t2', 'أحمد سعيد'), // 'مد' only mid-word ("أحمد") -> tier 2
      ];
      final results = service.search(mixed, 'مد');
      expect(results.map((final r) => r.holdingId).toList(), ['t1', 't2']);
      expect(results[0].score, greaterThan(results[1].score));
    });

    test('a completely absent query does not match', () {
      final results = service.search(parcels, 'زفت');
      expect(
        results.any((final r) => r.holdingId == '001117'),
        isFalse,
      );
    });

    test('non-matching name is excluded', () {
      final results = service.search(parcels, 'زينب فتحي عبدالله');
      expect(
        results.any((final r) => r.holdingId == '001117'),
        isFalse,
      );
    });

    test('groups by holding id and keeps best score, sorted descending', () {
      final results = service.search(parcels, 'محمد');
      for (var i = 0; i < results.length - 1; i++) {
        expect(results[i].score, greaterThanOrEqualTo(results[i + 1].score));
      }
      final ids = results.map((final r) => r.holdingId).toList();
      expect(ids.toSet().length, ids.length); // no duplicate holding ids
    });

    test('caps results at 10', () {
      final many = List.generate(
        20,
        (final i) => _parcel('id$i', 'محمد أحمد رقم $i'),
      );
      final results = service.search(many, 'محمد أحمد');
      expect(results.length, lessThanOrEqualTo(10));
    });
  });

  test('empty query returns no results', () {
    expect(service.search(parcels, '   '), isEmpty);
  });

  test(
      'two pending (not-yet-numbered) new people are not merged into one '
      'result — they share the same placeholder holdingId but have '
      'distinct ids, so grouping must key off Parcel.groupKey, not the '
      'raw holdingId', () {
    final List<Parcel> pending = <Parcel>[
      const Parcel(id: 'new-1', holdingId: '-', holderName: 'محمد الأول'),
      const Parcel(id: 'new-2', holdingId: '-', holderName: 'محمد الثاني'),
    ];

    final results = service.search(pending, 'محمد');

    expect(results, hasLength(2));
    expect(
      results.map((final r) => r.holderName).toSet(),
      <String>{'محمد الأول', 'محمد الثاني'},
    );
    expect(results[0].groupKey, isNot(results[1].groupKey));
  });

  group('reviewedCount', () {
    test('is 0 for a group with no reviewed parcels', () {
      final results = service.search(parcels, 'محمد أحمد علي');
      final match = results.firstWhere((final r) => r.holdingId == '001117');
      expect(match.reviewedCount, 0);
      expect(match.parcelCount, 2);
    });

    test('reflects a partially-reviewed group (some parcels reviewed)', () {
      final mixed = <Parcel>[
        const Parcel(holdingId: '900', holderName: 'خالد', reviewed: true),
        const Parcel(holdingId: '900', holderName: 'خالد'),
      ];
      final results = service.search(mixed, 'خالد');
      final match = results.first;
      expect(match.parcelCount, 2);
      expect(match.reviewedCount, 1);
    });

    test('reflects a fully-reviewed group', () {
      final fullyReviewed = <Parcel>[
        const Parcel(holdingId: '901', holderName: 'سامي', reviewed: true),
        const Parcel(holdingId: '901', holderName: 'سامي', reviewed: true),
      ];
      final results = service.search(fullyReviewed, 'سامي');
      final match = results.first;
      expect(match.parcelCount, 2);
      expect(match.reviewedCount, 2);
    });
  });
}
