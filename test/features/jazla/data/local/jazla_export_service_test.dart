import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';
import 'package:hiyaza_finder/features/jazla/data/local/jazla_export_service.dart';

void main() {
  const JazlaExportService service = JazlaExportService();

  test('export returns null for an empty parcel list', () {
    expect(service.export(jazlaName: 'جزلة', orderedParcels: const <Parcel>[]), isNull);
  });

  test('columns are in the exact spec order', () {
    expect(JazlaExportService.columns, <String>[
      'التسلسل',
      'اسم الحائز',
      'اسم المالك',
      'رقم الحيازة',
      'سهم',
      'قيراط',
      'فدان',
      'الملاحظات',
    ]);
  });

  test('rows carry 1-based التسلسل matching orderedParcels order', () {
    const List<Parcel> parcels = <Parcel>[
      Parcel(id: 'a', holdingId: '1', holderName: 'أ', feddan: 1, qirat: 2, sahm: 3),
      Parcel(id: 'b', holdingId: '2', holderName: 'ب', feddan: 4, qirat: 5, sahm: 6),
    ];

    final bytes = service.export(jazlaName: 'جزلة الري', orderedParcels: parcels);
    expect(bytes, isNotNull);

    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes!);
    final xlsx.Sheet sheet = workbook['جزلة الري'];

    // Row 0 is the header; rows 1.. are data.
    expect(sheet.rows[1][0]?.value.toString(), '1');
    expect(sheet.rows[2][0]?.value.toString(), '2');
    expect(sheet.rows[1][3]?.value.toString(), '1');
    expect(sheet.rows[2][3]?.value.toString(), '2');
  });

  test('notes are joined with "، "', () {
    const List<Parcel> parcels = <Parcel>[
      Parcel(id: 'a', holdingId: '1', notes: <String>['ملاحظة أ', 'ملاحظة ب']),
    ];

    final bytes = service.export(jazlaName: 'جزلة', orderedParcels: parcels);
    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes!);
    final xlsx.Sheet sheet = workbook['جزلة'];

    expect(sheet.rows[1][7]?.value.toString(), 'ملاحظة أ، ملاحظة ب');
  });

  test('buildFileName follows {city}_{jazla}_{dd}_{mm}_{yyyy}.xlsx', () {
    final DateTime now = DateTime.now();
    final String dd = now.day.toString().padLeft(2, '0');
    final String mm = now.month.toString().padLeft(2, '0');
    final String expected = 'شنشا_جزلة_الري_${dd}_${mm}_${now.year}.xlsx';

    expect(JazlaExportService.buildFileName('شنشا', 'جزلة الري'), expected);
  });

  test('buildFileName sanitizes spaces and dashes', () {
    final String result = JazlaExportService.buildFileName('city-1 name', 'my jazla');
    expect(result, contains('city_1_name_my_jazla_'));
  });
}
