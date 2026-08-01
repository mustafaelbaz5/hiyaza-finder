import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/domain/entities/parcel.dart';
import 'package:hiyaza_finder/features/holdings/domain/services/clipboard_formatter.dart';

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

    test('أوقاف credit type is rendered as the fixed sentence', () {
      const Parcel p = Parcel(holdingId: '55', creditType: 'أوقاف');
      final String text = formatter.format(p);
      expect(text, contains('نوع الائتمان: هذه الأرض تابعة لهيئة الأوقاف المصرية'));
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
