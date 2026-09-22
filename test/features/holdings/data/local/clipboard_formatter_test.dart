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
        id: 'uuid-123',
        holdingId: '101',
        holderName: 'محمد علي',
        ownerName: ownerName,
        isInheritance: isInheritance,
        isDelegate: isDelegate,
      );

  group('effective owner and display rules', () {
    test('owner falls back to holder', () {
      expect(formatter.effectiveOwnerName(baseParcel()), 'محمد علي');
    });

    test('inheritance without delegate prefixes holder and owner', () {
      final Parcel p = baseParcel(isInheritance: true);
      expect(formatter.holderNamePrefix(p), 'ورثة ');
      expect(formatter.ownerNamePrefix(p), 'ورثة ');
      expect(formatter.displayHolderName(p), 'ورثة محمد علي');
      expect(formatter.displayOwnerName(p), 'ورثة محمد علي');
    });

    test('delegate without inheritance does not prefix either name', () {
      final Parcel p = baseParcel(isDelegate: true);
      expect(formatter.holderNamePrefix(p), isNull);
      expect(formatter.ownerNamePrefix(p), isNull);
      expect(formatter.displayHolderName(p), 'محمد علي');
      expect(formatter.displayOwnerName(p), 'محمد علي');
    });

    test('inheritance with delegate prefixes owner only', () {
      final Parcel p = baseParcel(isInheritance: true, isDelegate: true);
      expect(formatter.holderNamePrefix(p), isNull);
      expect(formatter.ownerNamePrefix(p), 'ورثة ');
      expect(formatter.displayHolderName(p), 'محمد علي');
      expect(formatter.displayOwnerName(p), 'ورثة محمد علي');
    });
  });

  group('copy all format', () {
    test('uses id and pipe separators in the approved order', () {
      final String text = formatter.format(
        baseParcel().copyWith(
          associationName: 'جمعية الدير',
          basinName: 'الشيكارة',
          basinCode: 'B1',
          landNumber: '13113851',
          feddan: 1.0,
          qirat: 2.0,
          sahm: 3.0,
          usageType: 'زراعة',
          cropType: 'قمح',
          growthStages: 'مرحلة النمو الخضري',
          notes: const <String>['ملاحظة'],
        ),
      );

      expect(text.startsWith('id: uuid-123'), isTrue);
      expect(text, contains(' | رقم الحيازة: 101، عدد القطع: 1'));
      expect(text, contains('اسم الجمعية: جمعية الدير'));
      expect(text, contains('اسم الحوض: الشيكارة، كود الحوض: B1'));
      expect(text, contains('المساحة: 1 فدان، 2 قيراط، 3 سهم'));
      expect(text, contains('نوع المحصول: قمح'));
      expect(text, isNot(contains('\n')));
      expect(text, isNot(contains(';')));
    });

    test('normalizes line breaks inside notes', () {
      final String text = formatter.format(
        baseParcel().copyWith(
          notes: const <String>['ملاحظة أولى\nملاحظة ثانية'],
        ),
      );
      expect(text, contains('الملاحظات: ملاحظة أولى، ملاحظة ثانية'));
    });

    test('omits crop fields for non-agricultural usage', () {
      final String text = formatter.format(
        baseParcel().copyWith(usageType: 'مباني', cropType: 'قمح'),
      );
      expect(text, isNot(contains('نوع المحصول')));
      expect(text, isNot(contains('مرحلة النمو')));
    });

    test('uses placeholders for empty fields and preserves parcel data', () {
      final Parcel p = baseParcel().copyWith(nationalId: null);
      final String text = formatter.format(p);
      expect(text, contains('اسم الجمعية: -'));
      expect(text, contains('اسم الحوض: -'));
      expect(text, contains('رقم الأرض: 0'));
      expect(p.nationalId, isNull);
    });
  });
}
