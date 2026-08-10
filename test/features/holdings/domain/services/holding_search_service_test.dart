import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/domain/services/holding_search_service.dart';

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
    test('exact match scores 100 (tier 1)', () {
      final results = service.search(parcels, '001117');
      expect(results.first.holdingId, '001117');
      expect(results.first.score, 100);
      expect(results.first.parcelCount, 2);
    });

    test('prefix match scores 80 (tier 2)', () {
      final results = service.search(parcels, '0011');
      expect(results.map((final r) => r.holdingId), contains('001117'));
      final match = results.firstWhere((final r) => r.holdingId == '001117');
      expect(match.score, 80);
    });

    test('mid-string match scores 40 (tier 3, contains)', () {
      final results = service.search(parcels, '117');
      expect(results.map((final r) => r.holdingId), contains('001117'));
      final match = results.firstWhere((final r) => r.holdingId == '001117');
      expect(match.score, 40);
    });

    test(
        'exact match ranks above a holding number that merely contains the '
        'same digits (e.g. typing "7" ranks holding "7" above "470")', () {
      final withSevens = <Parcel>[
        _parcel('470', 'فلان الأول'),
        _parcel('7', 'فلان الثاني'),
        _parcel('71', 'فلان الثالث'),
      ];
      final results = service.search(withSevens, '7');
      expect(results.map((final r) => r.holdingId).toList(), [
        '7', // exact -> 100
        '71', // starts with -> 80
        '470', // contains -> 40
      ]);
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

  group('completedCount', () {
    test('is 0 for a group with no completed parcels', () {
      final results = service.search(parcels, 'محمد أحمد علي');
      final match = results.firstWhere((final r) => r.holdingId == '001117');
      expect(match.completedCount, 0);
      expect(match.parcelCount, 2);
    });

    test('reflects a partially-completed group (some parcels completed)', () {
      final DateTime now = DateTime.now();
      final mixed = <Parcel>[
        Parcel(holdingId: '900', holderName: 'خالد', completedAt: now),
        const Parcel(holdingId: '900', holderName: 'خالد'),
      ];
      final results = service.search(mixed, 'خالد');
      final match = results.first;
      expect(match.parcelCount, 2);
      expect(match.completedCount, 1);
    });

    test('reflects a fully-completed group', () {
      final DateTime now = DateTime.now();
      final fullyCompleted = <Parcel>[
        Parcel(holdingId: '901', holderName: 'سامي', completedAt: now),
        Parcel(holdingId: '901', holderName: 'سامي', completedAt: now),
      ];
      final results = service.search(fullyCompleted, 'سامي');
      final match = results.first;
      expect(match.parcelCount, 2);
      expect(match.completedCount, 2);
    });
  });

  group('isFieldAdded tiebreak (REFACTOR_ROADMAP.md Phase 7 — newly added '
      'parcels sort first)', () {
    test('field-added result ranks first when scores are tied', () {
      final tied = <Parcel>[
        const Parcel(
          id: 'imported-1',
          holdingId: '700',
          holderName: 'كريم محمد',
        ),
        const Parcel(
          id: 'added-1',
          holdingId: '701',
          holderName: 'كريم أحمد',
          isFieldAdded: true,
        ),
      ];

      final results = service.search(tied, 'كريم');

      expect(results, hasLength(2));
      expect(results[0].score, results[1].score); // both tier-1 full-name-start
      expect(results[0].isFieldAdded, isTrue);
      expect(results[0].holdingId, '701');
    });

    test('a higher-scoring imported result still ranks above a '
        'lower-scoring field-added one', () {
      final mixed = <Parcel>[
        const Parcel(
          id: 'imported-1',
          holdingId: '702',
          holderName: 'سعيد كريم', // 'كريم' matches mid-word -> tier 2
        ),
        const Parcel(
          id: 'added-1',
          holdingId: '703',
          holderName: 'أحمد آخر', // does not match 'كريم' at all
          isFieldAdded: true,
        ),
      ];

      final results = service.search(mixed, 'كريم');

      expect(results, hasLength(1));
      expect(results.first.holdingId, '702');
    });
  });
}
