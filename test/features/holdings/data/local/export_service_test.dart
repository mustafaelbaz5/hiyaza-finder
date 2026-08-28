import 'package:excel/excel.dart' as xlsx;
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/local/export_service.dart';
import 'package:hiyaza_finder/features/holdings/data/model/parcel.dart';

void main() {
  const ExportService service = ExportService();

  final List<Parcel> parcels = <Parcel>[
    const Parcel(
      id: 'p1',
      holdingId: '101',
      holderName: 'محمد علي',
      basinName: 'الباشا',
      cropType: 'قمح',
    ),
    const Parcel(
      id: 'p2',
      holdingId: '102',
      holderName: 'احمد فريد',
      basinName: 'البحيره',
      isFieldAdded: true,
    ),
  ];

  test('exportToExcel returns null when the scope has nothing to export', () {
    final bytes = service.exportToExcel(
      parcels: const <Parcel>[],
      scope: ExportScope.all,
    );
    expect(bytes, isNull);
  });

  test('all scope produces a sheet per basin plus the "all data" sheet', () {
    final bytes = service.exportToExcel(parcels: parcels, scope: ExportScope.all);
    expect(bytes, isNotNull);

    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes!);
    expect(workbook.tables.keys, containsAll(<String>['كل البيانات', 'الباشا', 'البحيره']));
  });

  test('the "all data" sheet has one header row plus one row per parcel', () {
    final bytes = service.exportToExcel(parcels: parcels, scope: ExportScope.all)!;
    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes);
    final xlsx.Sheet allSheet = workbook.tables['كل البيانات']!;
    expect(allSheet.maxRows, 1 + parcels.length); // header + 2 rows
  });

  test('a basin sheet only contains that basin\'s parcels', () {
    final bytes = service.exportToExcel(parcels: parcels, scope: ExportScope.all)!;
    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes);
    final xlsx.Sheet bashaSheet = workbook.tables['الباشا']!;
    expect(bashaSheet.maxRows, 2); // header + the one الباشا parcel
  });

  test('addedOnly scope excludes non-field-added parcels', () {
    final bytes = service.exportToExcel(
      parcels: parcels,
      scope: ExportScope.addedOnly,
    )!;
    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes);
    final xlsx.Sheet allSheet = workbook.tables['كل البيانات']!;
    expect(allSheet.maxRows, 2); // header + only the field-added parcel
    expect(workbook.tables.containsKey('الباشا'), isFalse); // that parcel isn't field-added
  });

  test('addedOnly scope with no field-added parcels returns null', () {
    final bytes = service.exportToExcel(
      parcels: const <Parcel>[Parcel(id: 'p3', holdingId: '103')],
      scope: ExportScope.addedOnly,
    );
    expect(bytes, isNull);
  });

  test('basinFilter narrows both the "all data" sheet and which basin sheets exist', () {
    final bytes = service.exportToExcel(
      parcels: parcels,
      scope: ExportScope.all,
      basinFilter: 'الباشا',
    )!;
    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes);
    expect(workbook.tables.keys, containsAll(<String>['كل البيانات', 'الباشا']));
    expect(workbook.tables.containsKey('البحيره'), isFalse);
    expect(workbook.tables['كل البيانات']!.maxRows, 2); // header + الباشا's one parcel
  });

  test('the header row matches ExportService.columns', () {
    final bytes = service.exportToExcel(parcels: parcels, scope: ExportScope.all)!;
    final xlsx.Excel workbook = xlsx.Excel.decodeBytes(bytes);
    final xlsx.Sheet allSheet = workbook.tables['كل البيانات']!;
    final List<String> headerRow = allSheet.rows.first
        .map((final xlsx.Data? cell) => (cell?.value as xlsx.TextCellValue?)?.value.toString() ?? '')
        .toList();
    expect(headerRow, ExportService.columns);
  });
}
