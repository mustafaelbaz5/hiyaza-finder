import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/holdings/data/excel/holdings_excel_parser.dart';
import 'package:hiyaza_finder/features/holdings/data/models/parcel.dart';

const String _sheetName = HoldingsExcelParser.sheetName;

Uint8List _buildWorkbook(final List<List<CellValue?>> rows) {
  final Excel excel = Excel.createExcel();
  excel.rename(excel.getDefaultSheet()!, _sheetName);
  for (final List<CellValue?> row in rows) {
    excel.appendRow(_sheetName, row);
  }
  return Uint8List.fromList(excel.encode()!);
}

List<CellValue?> _headerRow() => [
      TextCellValue('رقم الحيازة'),
      TextCellValue('رقم الصفحة بالسجل'),
      TextCellValue('المديريه'),
      TextCellValue('الأداره'),
      TextCellValue('اسم الحوض'),
      TextCellValue('كود الحوض'),
      TextCellValue('اسم الحائز'),
      TextCellValue('الرقم القومي'),
      TextCellValue('الحد الشرقى'),
      TextCellValue('الحد القبلى'),
      TextCellValue('الحد الغربى'),
      TextCellValue('الحد البحرى'),
      TextCellValue('رقم الأرض'),
      TextCellValue('فدان'),
      TextCellValue('قيراط'),
      TextCellValue('سهم'),
      TextCellValue('إجمالي المساحة (م²)'),
    ];

List<CellValue?> _dataRow({
  required final String holdingId,
  final String? holderName,
  final String? nationalId,
  final double? feddan,
}) =>
    [
      TextCellValue(holdingId),
      TextCellValue('1'),
      TextCellValue('مديرية'),
      TextCellValue('إدارة'),
      TextCellValue('حوض أ'),
      TextCellValue('B1'),
      holderName == null ? null : TextCellValue(holderName),
      nationalId == null ? null : TextCellValue(nationalId),
      TextCellValue('شرق'),
      TextCellValue('قبلي'),
      TextCellValue('غرب'),
      TextCellValue('بحري'),
      TextCellValue('L1'),
      feddan == null ? null : DoubleCellValue(feddan),
      const DoubleCellValue(1.0),
      const DoubleCellValue(2.0),
      const DoubleCellValue(4200.0),
    ];

void main() {
  const HoldingsExcelParser parser = HoldingsExcelParser();

  test('parses data rows, skips blank and totals rows', () {
    final Uint8List bytes = _buildWorkbook([
      _headerRow(),
      _dataRow(
        holdingId: '001117',
        holderName: 'محمد أحمد',
        nationalId: '00123456789',
        feddan: 1.5,
      ),
      List<CellValue?>.filled(17, null), // blank separator row
      _dataRow(holdingId: '001117', holderName: 'محمد أحمد'), // 2nd parcel
      _dataRow(holdingId: 'الإجمالي'), // totals row — skipped
      _dataRow(holdingId: ''), // empty holding id — skipped
      _dataRow(holdingId: '002200', holderName: 'علي حسن'),
    ]);

    final List<Parcel> parcels = parser.parse(bytes);

    expect(parcels.length, 3);
    expect(parcels[0].holdingId, '001117');
    expect(parcels[0].nationalId, '00123456789'); // leading zeros preserved
    expect(parcels[0].feddan, 1.5);
    expect(
        parcels.where((final Parcel p) => p.holdingId == '001117').length, 2);
    expect(parcels.any((final Parcel p) => p.holdingId == 'الإجمالي'), isFalse);
  });

  test('throws HoldingsParseException when a required column is missing', () {
    final List<CellValue?> incompleteHeader = _headerRow()..removeLast();
    final Uint8List bytes = _buildWorkbook([incompleteHeader]);

    expect(
      () => parser.parse(bytes),
      throwsA(isA<HoldingsParseException>()),
    );
  });
}
