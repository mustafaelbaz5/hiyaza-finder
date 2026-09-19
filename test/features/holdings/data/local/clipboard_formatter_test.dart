import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/local/clipboard_formatter.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

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

  // The ورثة/مفوض prefix matrix (UI/UX Updates prompt "Change 1"/"Change
  // 2"): اسم الحائز is NEVER prefixed regardless of either toggle — مفوض is
  // represented only via the auto ملاحظات entry. اسم المالك gets "ورثة "
  // (no brackets, trailing space) when ورثة is set, unaffected by مفوض.
  group('ورثة/مفوض prefix matrix', () {
    test('neither toggle on — no prefix on either slot', () {
      final String text = formatter.format(baseParcel());
      expect(text, contains('اسم المالك: محمد علي'));
      expect(text, contains('اسم الحائز: محمد علي'));
    });

    test('ورثة alone — owner gets "ورثة ", holder stays unprefixed', () {
      final String text = formatter.format(baseParcel(isInheritance: true));
      expect(text, contains('اسم المالك: ورثة محمد علي'));
      expect(text, contains('اسم الحائز: محمد علي'));
    });

    test(
      'مفوض alone — neither slot is prefixed; مفوض only shows via ملاحظات',
      () {
        final String text = formatter.format(baseParcel(isDelegate: true));
        expect(text, contains('اسم المالك: محمد علي'));
        expect(text, contains('اسم الحائز: محمد علي'));
      },
    );

    test(
      'ورثة + مفوض together — owner still gets "ورثة ", holder unprefixed',
      () {
        final String text = formatter.format(
          baseParcel(isInheritance: true, isDelegate: true),
        );
        expect(text, contains('اسم المالك: ورثة محمد علي'));
        expect(text, contains('اسم الحائز: محمد علي'));
      },
    );
  });

  // holderNamePrefix/ownerNamePrefix back the on-screen اسم الحائز/اسم المالك
  // display — same rule as the matrix above, asserted directly against the
  // prefix strings themselves rather than through the full clipboard text.
  group('holderNamePrefix/ownerNamePrefix', () {
    test('neither toggle on — both null', () {
      final Parcel p = baseParcel();
      expect(formatter.holderNamePrefix(p), isNull);
      expect(formatter.ownerNamePrefix(p), isNull);
    });

    test('ورثة alone — owner gets "ورثة ", holder stays null', () {
      final Parcel p = baseParcel(isInheritance: true);
      expect(formatter.holderNamePrefix(p), isNull);
      expect(formatter.ownerNamePrefix(p), 'ورثة ');
    });

    test('مفوض alone — both stay null (مفوض never prefixes a name)', () {
      final Parcel p = baseParcel(isDelegate: true);
      expect(formatter.holderNamePrefix(p), isNull);
      expect(formatter.ownerNamePrefix(p), isNull);
    });

    test('ورثة + مفوض together — holder still null, owner keeps "ورثة "', () {
      final Parcel p = baseParcel(isInheritance: true, isDelegate: true);
      expect(formatter.holderNamePrefix(p), isNull);
      expect(formatter.ownerNamePrefix(p), 'ورثة ');
    });
  });

  group('format', () {
    test('parcel code line is always first', () {
      const Parcel p = Parcel(id: 'uuid-123', holdingId: '55');
      final String text = formatter.format(p);
      expect(text.split('\n').first, 'كود القطعة: uuid-123');
    });

    test('رقم الأرض comes right after كود الحوض', () {
      const Parcel p = Parcel(
        holdingId: '55',
        basinCode: 'B1',
        landNumber: '13113851',
      );
      final List<String> lines = formatter.format(p).split('\n');
      expect(lines, contains('اسم الحوض: -، كود الحوض: B1'));
      expect(lines, contains('رقم الأرض: 13113851'));
    });

    test('رقم الأرض falls back to "0" when missing', () {
      const Parcel p = Parcel(holdingId: '55');
      expect(formatter.format(p), contains('رقم الأرض: 0'));
    });

    test('رقم الأرض falls back to "0" for a field-added parcel', () {
      const Parcel p = Parcel(
        holdingId: '55',
        landNumber: '13113851',
        isFieldAdded: true,
      );
      expect(formatter.format(p), contains('رقم الأرض: 0'));
    });

    test('blank/empty fields render the placeholder, never skipped', () {
      const Parcel p = Parcel(holdingId: '55');
      final String text = formatter.format(p);
      expect(text, contains('اسم الحائز: -'));
      expect(text, contains('اسم الحوض: -'));
      expect(text, contains('كود الحوض: -'));
    });

    test(
        'missing national id shows the 14-ones display default, never '
        'stored', () {
      const Parcel p = Parcel(holdingId: '55');
      final String text = formatter.format(p);
      expect(text, contains('الرقم القومي: 11111111111111'));
      expect(p.nationalId, isNull);
    });

    test('عدد القطع defaults to 1 when holdingsCount is null or 0', () {
      const Parcel nullCount = Parcel(holdingId: '55');
      const Parcel zeroCount = Parcel(holdingId: '55', holdingsCount: 0);
      expect(formatter.format(nullCount), contains('عدد القطع: 1'));
      expect(formatter.format(zeroCount), contains('عدد القطع: 1'));
    });

    test('عدد القطع reflects a real count above 1', () {
      const Parcel p = Parcel(holdingId: '55', holdingsCount: 3);
      expect(formatter.format(p), contains('عدد القطع: 3'));
    });

    test(
        'credit fields and total square meters are never Copy All fields '
        '(association name and land number are included)', () {
      const Parcel p = Parcel(
        holdingId: '55',
        creditType: 'أوقاف',
        associationName: 'جمعية الدير',
        landNumber: '13113851',
        totalSqm: 2450.49,
        notes: <String>['الأرض تابعة لهيئة الأوقاف المصرية'],
      );
      final String text = formatter.format(p);
      expect(text, isNot(contains('نوع الائتمان')));
      expect(text, isNot(contains('نوع الإصلاح')));
      expect(text, contains('اسم الجمعية: جمعية الدير'));
      expect(text, isNot(contains('المساحة بالمتر')));
      expect(text, contains('رقم الأرض: 13113851'));
      expect(text, contains('الأرض تابعة لهيئة الأوقاف المصرية'));
    });

    test('area values share one compact line', () {
      const Parcel p = Parcel(holdingId: '55', feddan: 1, qirat: 2, sahm: 3);
      final List<String> lines = formatter.format(p).split('\n');
      expect(lines, contains('المساحة: 1 فدان، 2 قيراط، 3 سهم'));
    });

    test(
        'رقم الحيازة/عدد القطع share one line (Copy All height-reduction '
        'prompt)', () {
      const Parcel p = Parcel(holdingId: '55', holdingsCount: 3);
      final List<String> lines = formatter.format(p).split('\n');
      expect(lines, contains('رقم الحيازة: 55، عدد القطع: 3'));
    });

    test('uses newlines as separators and no semicolons', () {
      const Parcel p = Parcel(
        holdingId: '55',
        feddan: 1,
        qirat: 2,
        sahm: 3,
        notes: <String>['ملاحظة'],
      );
      final String text = formatter.format(p);
      expect(text, contains('\n'));
      expect(text, isNot(contains(';')));
    });

    test('normalizes line breaks inside notes', () {
      const Parcel p = Parcel(
        holdingId: '55',
        notes: <String>['ملاحظة أولى\nملاحظة ثانية'],
      );
      expect(
        formatter.format(p),
        contains('الملاحظات: ملاحظة أولى، ملاحظة ثانية'),
      );
    });

    test('نوع المحصول/مرحلة النمو show for زراعة usage', () {
      const Parcel p = Parcel(
        holdingId: '55',
        usageType: 'زراعة',
        cropType: 'قمح',
        growthStages: 'مرحلة النمو الخضري',
      );
      final String text = formatter.format(p);
      expect(text, contains('نوع المحصول: قمح'));
      expect(text, contains('مرحلة النمو: مرحلة النمو الخضري'));
    });

    test('نوع المحصول/مرحلة النمو are omitted for مباني/بور usage', () {
      const Parcel buildings = Parcel(holdingId: '55', usageType: 'مباني');
      const Parcel fallow = Parcel(holdingId: '55', usageType: 'بور');
      expect(formatter.format(buildings), isNot(contains('نوع المحصول')));
      expect(formatter.format(buildings), isNot(contains('مرحلة النمو:')));
      expect(formatter.format(fallow), isNot(contains('نوع المحصول')));
      expect(formatter.format(fallow), isNot(contains('مرحلة النمو:')));
    });

    test('ملاحظات line is omitted entirely when there are no notes', () {
      const Parcel p = Parcel(holdingId: '55');
      final String text = formatter.format(p);
      expect(text, isNot(contains('الملاحظات')));
    });

    test('ملاحظات line appears, joined by "، ", when notes are present', () {
      const Parcel p = Parcel(
        holdingId: '55',
        notes: <String>['ملاحظة أولى', 'ملاحظة ثانية'],
      );
      final String text = formatter.format(p);
      expect(text, contains('الملاحظات: ملاحظة أولى، ملاحظة ثانية'));
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
