import 'dart:typed_data';

import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../../domain/entities/parcel.dart';

/// Thrown when the workbook is missing one or more required columns.
class HoldingsParseException implements Exception {
  HoldingsParseException(this.missingColumns);

  final List<String> missingColumns;

  @override
  String toString() =>
      'HoldingsParseException(missingColumns: $missingColumns)';
}

/// Parses the `.xlsx` produced by the desktop tool into a flat [Parcel] list.
///
/// Mirrors `output_file_reader.py`: columns are located by header text (not
/// fixed index), data starts on row 2, blank/totals rows are skipped, and
/// holding/national IDs are read as text to preserve leading zeros.
///
/// Uses `spreadsheet_decoder` rather than the `excel` package because the
/// latter throws "Null check operator used on a null value" on some valid
/// workbooks (fragile style/number-format parsing). `spreadsheet_decoder`
/// returns plain cell values (`String`/`num`/`bool`/`null`) and is far more
/// tolerant of how the source file was written.
class HoldingsExcelParser {
  const HoldingsExcelParser();

  static const String sheetName = 'البيانات المجمعة';
  static const String _totalsMarker = 'الإجمالي';

  static const _headers = <String>[
    'رقم الحيازة',
    'رقم الصفحة بالسجل',
    'المديريه',
    'الأداره',
    'اسم الحوض',
    'كود الحوض',
    'اسم الحائز',
    'الرقم القومي',
    'الحد الشرقى',
    'الحد القبلى',
    'الحد الغربى',
    'الحد البحرى',
    'رقم الأرض',
    'فدان',
    'قيراط',
    'سهم',
    'إجمالي المساحة (م²)',
  ];

  List<Parcel> parse(final Uint8List bytes) {
    final SpreadsheetDecoder decoder = SpreadsheetDecoder.decodeBytes(bytes);
    final SpreadsheetTable? table = decoder.tables[sheetName];
    if (table == null) {
      throw HoldingsParseException([sheetName]);
    }

    final List<List<dynamic>> rows = table.rows;
    if (rows.isEmpty) {
      throw HoldingsParseException(_headers);
    }

    final List<dynamic> headerRow = rows.first;
    final columnIndex = <String, int>{};
    for (var i = 0; i < headerRow.length; i++) {
      final String? text = _cellText(headerRow[i]);
      if (text != null && text.isNotEmpty) {
        columnIndex[text] = i;
      }
    }

    final missing =
        _headers.where((final h) => !columnIndex.containsKey(h)).toList();
    if (missing.isNotEmpty) {
      throw HoldingsParseException(missing);
    }

    String? textAt(final List<dynamic> row, final String header) {
      final int idx = columnIndex[header]!;
      if (idx >= row.length) return null;
      return _cellText(row[idx]);
    }

    double? numAt(final List<dynamic> row, final String header) {
      final int idx = columnIndex[header]!;
      if (idx >= row.length) return null;
      return _cellNumber(row[idx]);
    }

    final parcels = <Parcel>[];
    for (var r = 1; r < rows.length; r++) {
      final List<dynamic> row = rows[r];
      if (_isBlankRow(row)) continue;

      final String? holdingId = textAt(row, 'رقم الحيازة');
      if (holdingId == null || holdingId.isEmpty) continue;
      if (holdingId == _totalsMarker) continue;

      parcels.add(
        Parcel(
          holdingId: holdingId,
          pageNumber: textAt(row, 'رقم الصفحة بالسجل'),
          directorate: textAt(row, 'المديريه'),
          administration: textAt(row, 'الأداره'),
          basinName: textAt(row, 'اسم الحوض'),
          basinCode: textAt(row, 'كود الحوض'),
          holderName: textAt(row, 'اسم الحائز'),
          nationalId: textAt(row, 'الرقم القومي'),
          borderEast: textAt(row, 'الحد الشرقى'),
          borderSouth: textAt(row, 'الحد القبلى'),
          borderWest: textAt(row, 'الحد الغربى'),
          borderNorth: textAt(row, 'الحد البحرى'),
          landNumber: textAt(row, 'رقم الأرض'),
          feddan: numAt(row, 'فدان'),
          qirat: numAt(row, 'قيراط'),
          sahm: numAt(row, 'سهم'),
          totalSqm: numAt(row, 'إجمالي المساحة (م²)'),
        ),
      );
    }

    return parcels;
  }

  bool _isBlankRow(final List<dynamic> row) {
    return row.every((final dynamic cell) => _cellText(cell) == null);
  }

  /// Reads a cell as a trimmed non-empty string, or `null` when empty.
  /// Integral doubles (e.g. `1117.0`) are rendered without the fractional
  /// part so numeric-looking text keeps a clean value.
  String? _cellText(final dynamic value) {
    if (value == null) return null;
    if (value is double && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  double? _cellNumber(final dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }
}
