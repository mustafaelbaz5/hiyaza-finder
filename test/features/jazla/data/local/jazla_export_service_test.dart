import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/jazla/data/local/jazla_export_service.dart';
import 'package:hiyaza_finder/features/jazla/data/model/jazla.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

void main() {
  const JazlaExportService service = JazlaExportService();

  Jazla jazla() => Jazla(
        id: 'jazla-1',
        cityId: 'city-1',
        name: 'جزلة الري',
        basinName: 'حوض النيل',
        targetAreaSqmOverride: 2000,
        createdAt: DateTime.utc(2026),
      );

  test('empty Jazla does not create an export file', () {
    expect(
      service.export(jazla: jazla(), orderedParcels: const <Parcel>[]),
      isNull,
    );
  });

  test('report includes metadata and operational table headers', () {
    expect(JazlaExportService.columns, <String>[
      'id',
      'رقم الحيازة',
      'اسم الحائز',
      'اسم المالك',
      'المساحة',
      'نوع الاستخدام',
      'نوع المحصول',
      'الملاحظات',
    ]);

    const List<Parcel> parcels = <Parcel>[
      Parcel(
        id: 'parcel-a',
        holdingId: '1',
        holderName: 'أ',
        feddan: 1,
        qirat: 2,
        sahm: 3,
      ),
    ];
    final bytes = service.export(jazla: jazla(), orderedParcels: parcels);
    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes!);
    final xlsx.Sheet sheet = workbook['جزلة الري'];

    expect(sheet.rows[0][0]?.value.toString(), contains('تقرير جزلة'));
    expect(sheet.rows[1][0]?.value.toString(), 'الحوض');
    expect(sheet.rows[1][1]?.value.toString(), 'حوض النيل');
    final List<xlsx.Data?> header = sheet.rows.firstWhere(
      (final List<xlsx.Data?> row) => row.first?.value.toString() == 'id',
    );
    expect(header, hasLength(8));
    expect(header[0]?.value.toString(), 'id');
    expect(header[1]?.value.toString(), 'رقم الحيازة');
    expect(header[4]?.value.toString(), 'المساحة');
    expect(header[7]?.value.toString(), 'الملاحظات');
  });

  test('table retains Jazla parcel order and joins notes', () {
    const List<Parcel> parcels = <Parcel>[
      Parcel(
        id: 'first',
        holdingId: '1',
        holderName: 'الأول',
        ownerName: 'مالك الأول',
        feddan: 1,
        qirat: 2,
        sahm: 3,
        cropType: 'قمح',
        notes: <String>['ملاحظة أ', 'ملاحظة ب'],
      ),
      Parcel(id: 'second', holdingId: '2', holderName: 'الثاني'),
    ];
    final bytes = service.export(jazla: jazla(), orderedParcels: parcels);
    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes!);
    final xlsx.Sheet sheet = workbook['جزلة الري'];

    final int headerIndex = sheet.rows.indexWhere(
      (final List<xlsx.Data?> row) => row.first?.value.toString() == 'id',
    );
    final List<xlsx.Data?> firstDataRow = sheet.rows[headerIndex + 1];
    final List<xlsx.Data?> secondDataRow = sheet.rows[headerIndex + 2];
    expect(firstDataRow[0]?.value.toString(), 'first');
    expect(secondDataRow[0]?.value.toString(), 'second');
    expect(firstDataRow[1]?.value.toString(), '1');
    expect(firstDataRow[2]?.value.toString(), 'الأول');
    expect(firstDataRow[3]?.value.toString(), 'مالك الأول');
    expect(firstDataRow[4]?.value.toString(), '1 فدان، 2 قيراط، 3 سهم');
    expect(firstDataRow[5]?.value.toString(), Parcel.defaultUsageType);
    expect(firstDataRow[6]?.value.toString(), 'قمح');
    expect(firstDataRow[7]?.value.toString(), 'ملاحظة أ، ملاحظة ب');
  });

  test('buildFileName follows {city}_{jazla}_{dd}_{mm}_{yyyy}.xlsx', () {
    final DateTime now = DateTime.now();
    final String dd = now.day.toString().padLeft(2, '0');
    final String mm = now.month.toString().padLeft(2, '0');
    final String expected = 'شنشا_جزلة_الري_${dd}_${mm}_${now.year}.xlsx';

    expect(JazlaExportService.buildFileName('شنشا', 'جزلة الري'), expected);
  });

  test('buildFileName sanitizes spaces and dashes', () {
    final String result =
        JazlaExportService.buildFileName('city-1 name', 'my jazla');

    expect(result, contains('city_1_name_my_jazla_'));
  });
}
