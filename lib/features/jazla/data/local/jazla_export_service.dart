import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;

import '../../../parcel_catalog/data/local/area_calculator.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../../../parcel_details/data/local/clipboard_formatter.dart';
import '../model/jazla.dart';

/// Builds a print-friendly, RTL Jazla workbook while preserving the Jazla's
/// parcel order. The source remains local only; no export mutates Jazla data.
class JazlaExportService {
  const JazlaExportService({
    final ClipboardFormatter formatter = const ClipboardFormatter(),
  }) : _formatter = formatter;

  final ClipboardFormatter _formatter;

  static const List<String> columns = <String>[
    'id',
    'رقم الحيازة',
    'اسم الحائز',
    'اسم المالك',
    'فدان',
    'قيراط',
    'سهم',
    'نوع الاستخدام',
    'نوع المحصول',
    'الملاحظات',
  ];

  Uint8List? export({
    required final Jazla jazla,
    required final List<Parcel> orderedParcels,
  }) {
    if (orderedParcels.isEmpty) return null;

    final xlsx.Excel workbook = xlsx.Excel.createExcel();
    final String sheetName = _sheetName(jazla.name);
    final xlsx.Sheet sheet = workbook[sheetName];
    sheet.isRTL = true;
    _setColumnWidths(sheet);
    _writeReportHeader(sheet, jazla, orderedParcels);
    _writeTable(sheet, orderedParcels);

    final String? defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      workbook.delete(defaultSheet);
    }

    final List<int>? bytes = workbook.save();
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  void _writeReportHeader(
    final xlsx.Sheet sheet,
    final Jazla jazla,
    final List<Parcel> parcels,
  ) {
    final double addedArea = _addedArea(parcels);
    final double? targetArea = jazla.targetAreaSqm;
    final double? difference =
        targetArea == null ? null : targetArea - addedArea;

    sheet.merge(
      xlsx.CellIndex.indexByString('A1'),
      xlsx.CellIndex.indexByString('J1'),
      customValue: xlsx.TextCellValue('تقرير جزلة: ${jazla.name}'),
    );
    sheet.cell(xlsx.CellIndex.indexByString('A1')).cellStyle = _titleStyle;
    sheet.setRowHeight(0, 28);

    _writeMetaRow(sheet, 1, 'الحوض', jazla.basinName ?? '—', 'عدد القطع',
        '${parcels.length}');
    _writeMetaRow(
      sheet,
      2,
      'المساحة المستهدفة',
      targetArea == null ? '—' : _formatArea(targetArea),
      'المساحة المضافة',
      _formatArea(addedArea),
    );
    _writeMetaRow(
      sheet,
      3,
      'الفرق',
      difference == null ? '—' : _formatArea(difference.abs()),
      'تاريخ التصدير',
      _dateLabel(DateTime.now()),
    );
  }

  void _writeMetaRow(
    final xlsx.Sheet sheet,
    final int row,
    final String firstLabel,
    final String firstValue,
    final String secondLabel,
    final String secondValue,
  ) {
    final List<xlsx.CellValue> values = <xlsx.CellValue>[
      xlsx.TextCellValue(firstLabel),
      xlsx.TextCellValue(firstValue),
      xlsx.TextCellValue(secondLabel),
      xlsx.TextCellValue(secondValue),
    ];
    for (int column = 0; column < 4; column++) {
      final xlsx.Data cell = sheet.cell(
        xlsx.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      );
      cell.value = values[column];
      cell.cellStyle = column.isEven ? _metaLabelStyle : _metaValueStyle;
    }
  }

  void _writeTable(final xlsx.Sheet sheet, final List<Parcel> parcels) {
    const int headerRow = 5;
    for (int column = 0; column < columns.length; column++) {
      final xlsx.Data cell = sheet.cell(
        xlsx.CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: headerRow,
        ),
      );
      cell.value = xlsx.TextCellValue(columns[column]);
      cell.cellStyle = _tableHeaderStyle;
    }
    sheet.setRowHeight(headerRow, 24);

    for (int index = 0; index < parcels.length; index++) {
      final Parcel parcel = parcels[index];
      final List<xlsx.CellValue> values = _rowFor(parcel);
      final xlsx.CellStyle style =
          index.isEven ? _rowStyle : _alternateRowStyle;
      final int row = headerRow + index + 1;
      for (int column = 0; column < columns.length; column++) {
        final xlsx.Data cell = sheet.cell(
          xlsx.CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        );
        cell.value = values[column];
        cell.cellStyle = style;
      }
    }
  }

  List<xlsx.CellValue> _rowFor(final Parcel parcel) {
    return <xlsx.CellValue>[
      _textCell(parcel.id),
      _textCell(parcel.holdingId),
      _textCell(_formatter.displayHolderName(parcel)),
      _textCell(_formatter.displayOwnerName(parcel)),
      _numberCell(parcel.feddan),
      _numberCell(parcel.qirat),
      _numberCell(parcel.sahm),
      _textCell(parcel.usageType),
      _textCell(parcel.cropType),
      _textCell(parcel.notes.isEmpty ? null : parcel.notes.join('، ')),
    ];
  }

  xlsx.CellValue _textCell(final String? value) {
    final String text = value?.trim() ?? '';
    return xlsx.TextCellValue(text.isEmpty ? '—' : text);
  }

  xlsx.CellValue _numberCell(final double? value) =>
      value == null ? xlsx.TextCellValue('—') : xlsx.DoubleCellValue(value);

  double _addedArea(final List<Parcel> parcels) => parcels.fold<double>(
        0,
        (final double total, final Parcel parcel) =>
            total +
            (AreaCalculator.totalSqm(
                  feddan: parcel.feddan,
                  qirat: parcel.qirat,
                  sahm: parcel.sahm,
                ) ??
                0),
      );

  void _setColumnWidths(final xlsx.Sheet sheet) {
    const List<double> widths = <double>[
      36,
      16,
      30,
      30,
      12,
      12,
      12,
      18,
      20,
      44
    ];
    for (int index = 0; index < widths.length; index++) {
      sheet.setColumnWidth(index, widths[index]);
    }
  }

  static String _sheetName(final String name) {
    final String clean = name.replaceAll(RegExp(r'[\\/:*?\[\]]'), '_').trim();
    if (clean.isEmpty) return 'جزلة';
    return clean.length <= 31 ? clean : clean.substring(0, 31);
  }

  static String _formatArea(final double value) =>
      '${value.toStringAsFixed(2)} م²';

  static String _dateLabel(final DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static final xlsx.CellStyle _titleStyle = xlsx.CellStyle(
    backgroundColorHex: xlsx.ExcelColor.fromHexString('FF409B69'),
    fontColorHex: xlsx.ExcelColor.white,
    fontSize: 15,
    bold: true,
    horizontalAlign: xlsx.HorizontalAlign.Center,
    verticalAlign: xlsx.VerticalAlign.Center,
  );
  static final xlsx.CellStyle _metaLabelStyle = xlsx.CellStyle(
    backgroundColorHex: xlsx.ExcelColor.fromHexString('FFE2F2E9'),
    fontColorHex: xlsx.ExcelColor.fromHexString('FF20643F'),
    bold: true,
    horizontalAlign: xlsx.HorizontalAlign.Right,
  );
  static final xlsx.CellStyle _metaValueStyle = xlsx.CellStyle(
    horizontalAlign: xlsx.HorizontalAlign.Right,
    textWrapping: xlsx.TextWrapping.WrapText,
  );
  static final xlsx.CellStyle _tableHeaderStyle = xlsx.CellStyle(
    backgroundColorHex: xlsx.ExcelColor.fromHexString('FF20643F'),
    fontColorHex: xlsx.ExcelColor.white,
    bold: true,
    horizontalAlign: xlsx.HorizontalAlign.Center,
    verticalAlign: xlsx.VerticalAlign.Center,
    textWrapping: xlsx.TextWrapping.WrapText,
  );
  static final xlsx.CellStyle _rowStyle = xlsx.CellStyle(
    horizontalAlign: xlsx.HorizontalAlign.Right,
    verticalAlign: xlsx.VerticalAlign.Center,
    textWrapping: xlsx.TextWrapping.WrapText,
  );
  static final xlsx.CellStyle _alternateRowStyle = xlsx.CellStyle(
    backgroundColorHex: xlsx.ExcelColor.fromHexString('FFF3F8F5'),
    horizontalAlign: xlsx.HorizontalAlign.Right,
    verticalAlign: xlsx.VerticalAlign.Center,
    textWrapping: xlsx.TextWrapping.WrapText,
  );

  static String buildFileName(final String cityName, final String jazlaName) {
    final DateTime now = DateTime.now();
    final String dd = now.day.toString().padLeft(2, '0');
    final String mm = now.month.toString().padLeft(2, '0');
    final String cleanCity =
        cityName.replaceAll('-', '_').replaceAll(' ', '_').trim();
    final String cleanJazla =
        jazlaName.replaceAll('-', '_').replaceAll(' ', '_').trim();
    return '${cleanCity}_${cleanJazla}_${dd}_${mm}_${now.year}.xlsx';
  }
}
