import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/holdings/data/local/clipboard_formatter.dart';

void main() {
  const ClipboardFormatter formatter = ClipboardFormatter();

  Parcel baseParcel({
    final bool isInheritance = false,
    final bool isDelegate = false,
    final String? ownerName,
  }) =>
      Parcel(
        holdingId: '101',
        holderName: 'محمد علي',
        ownerName: ownerName,
        isInheritance: isInheritance,
        isDelegate: isDelegate,
      );

  group('effectiveOwnerName', () {
    test('falls back to holderName when ownerName is unset', () {
      final Parcel p = baseParcel();
      expect(formatter.effectiveOwnerName(p), 'محمد علي');
    });

    test('prefers an explicit ownerName over holderName', () {
      final Parcel p = baseParcel(ownerName: 'احمد فريد');
      expect(formatter.effectiveOwnerName(p), 'احمد فريد');
    });

    test('treats a blank ownerName as unset', () {
      final Parcel p = baseParcel(ownerName: '   ');
      expect(formatter.effectiveOwnerName(p), 'محمد علي');
    });
  });

  // The وراثة/مفوض prefix matrix: four distinct combinations, each with a
  // specific, previously user-specified expected outcome for the holder
  // slot (اسم الحائز) and the owner slot (اسم المالك).
  group('وراثة/مفوض prefix matrix', () {
    test('neither toggle on — no prefix on either slot', () {
      final String text = formatter.format(baseParcel());
      expect(text, contains('اسم المالك: محمد علي,'));
      expect(text, contains('اسم الحائز: محمد علي,'));
    });

    test('وراثة alone — both slots get (ورثة)', () {
      final String text = formatter.format(baseParcel(isInheritance: true));
      expect(text, contains('اسم المالك: (ورثة) محمد علي,'));
      expect(text, contains('اسم الحائز: (ورثة) محمد علي,'));
    });

    test(
      'مفوض alone — only the holder slot gets (مفوض عنه); owner untouched',
      () {
        final String text = formatter.format(baseParcel(isDelegate: true));
        expect(text, contains('اسم المالك: محمد علي,'));
        expect(text, contains('اسم الحائز: (مفوض عنه) محمد علي,'));
      },
    );

    test(
      'وراثة + مفوض together — holder gets (مفوض عنه), owner keeps (ورثة)',
      () {
        final String text = formatter.format(
          baseParcel(isInheritance: true, isDelegate: true),
        );
        expect(text, contains('اسم المالك: (ورثة) محمد علي,'));
        expect(text, contains('اسم الحائز: (مفوض عنه) محمد علي,'));
      },
    );
  });

  // holderNamePrefix/ownerNamePrefix back the on-screen اسم الحائز/اسم المالك
  // display (REFACTOR_ROADMAP.md Phase 10 §6) — same rule as the matrix
  // above, asserted directly against the prefix strings themselves rather
  // than through the full clipboard text.
  group('holderNamePrefix/ownerNamePrefix', () {
    test('neither toggle on — both null', () {
      final Parcel p = baseParcel();
      expect(formatter.holderNamePrefix(p), isNull);
      expect(formatter.ownerNamePrefix(p), isNull);
    });

    test('وراثة alone — both get (ورثة)', () {
      final Parcel p = baseParcel(isInheritance: true);
      expect(formatter.holderNamePrefix(p), '(ورثة)');
      expect(formatter.ownerNamePrefix(p), '(ورثة)');
    });

    test('مفوض alone — only holder gets (مفوض عنه), owner stays null', () {
      final Parcel p = baseParcel(isDelegate: true);
      expect(formatter.holderNamePrefix(p), '(مفوض عنه)');
      expect(formatter.ownerNamePrefix(p), isNull);
    });

    test('وراثة + مفوض together — holder (مفوض عنه) wins, owner keeps (ورثة)',
        () {
      final Parcel p = baseParcel(isInheritance: true, isDelegate: true);
      expect(formatter.holderNamePrefix(p), '(مفوض عنه)');
      expect(formatter.ownerNamePrefix(p), '(ورثة)');
    });
  });

  group('format', () {
    test('blank/empty fields render the placeholder, never skipped', () {
      const Parcel p = Parcel(holdingId: '55');
      final String text = formatter.format(p);
      expect(text, contains('اسم الحائز: -,'));
      expect(text, contains('اسم الحوض: -,'));
      expect(text, contains('ملاحظات: -,'));
    });

    test('missing national id is padded with 14 ones', () {
      const Parcel p = Parcel(holdingId: '55');
      final String text = formatter.format(p);
      expect(text, contains('الرقم القومي: 11111111111111,'));
    });

    test(
        'نوع الائتمان/نوع الإصلاح is never a Copy All field '
        '(Credit/Reform Type Logic prompt — surfaces via ملاحظات only)', () {
      const Parcel p = Parcel(
        holdingId: '55',
        creditType: 'أوقاف',
        notes: <String>['الأرض تابعة لهيئة الأوقاف المصرية'],
      );
      final String text = formatter.format(p);
      expect(text, isNot(contains('نوع الائتمان')));
      expect(text, isNot(contains('نوع الإصلاح')));
      expect(text, contains('الأرض تابعة لهيئة الأوقاف المصرية'));
    });

    test('فدان/قيراط/سهم share one line', () {
      const Parcel p = Parcel(holdingId: '55', feddan: 1, qirat: 2, sahm: 3);
      final String text = formatter.format(p);
      final String feddanLine =
          text.split('\n').firstWhere((final String line) => line.contains('فدان:'));
      expect(feddanLine, contains('فدان: 1,'));
      expect(feddanLine, contains('قيراط: 2,'));
      expect(feddanLine, contains('سهم: 3,'));
    });
  });

  group('formatNumber', () {
    test('whole numbers drop the decimal point', () {
      expect(formatter.formatNumber(4), '4');
    });

    test('fractional numbers keep their decimals', () {
      expect(formatter.formatNumber(4.5), '4.5');
    });

    test('null returns null', () {
      expect(formatter.formatNumber(null), isNull);
    });
  });
}
