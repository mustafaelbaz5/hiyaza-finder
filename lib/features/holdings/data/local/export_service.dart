import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;

import '../model/parcel.dart';
import 'clipboard_formatter.dart';

/// Which parcels an export includes.
enum ExportScope { all, addedOnly }

/// Builds an in-memory .xlsx workbook from the active dataset — one sheet
/// per اسم الحوض present in scope, plus a "كل البيانات" sheet with every
/// row. All values come straight from `HoldingsRepository.parcels`, which
/// already has the local edit overlay applied — there is no separate
/// remote/local merge to do here.
class ExportService {
  const ExportService({
    final ClipboardFormatter formatter = const ClipboardFormatter(),
  }) : _formatter = formatter;

  final ClipboardFormatter _formatter;

  static const String _allDataSheetName = 'كل البيانات';

  static const List<String> columns = <String>[
    'كود القطعة',
    'رقم الحيازة',
    'كود الجمعية + اسم الجمعية',
    'نوع الجمعية',
    'اسم المالك من الحصر الميداني',
    'الرقم القومي',
    'اسم الحائز من الحصر الميداني',
    'رقم القطعة',
    'فدان',
    'قيراط',
    'سهم',
    'كود الحوض + اسم الحوض',
    'نوع الاستخدام',
    'نوع المحصول',
    'مراحل النمو',
    'ملاحظات من فريق العمل',
  ];

  /// `null` if [scope]/[basinFilter] leave nothing to export.
  Uint8List? exportToExcel({
    required final List<Parcel> parcels,
    required final ExportScope scope,
    final String? basinFilter,
  }) {
    final List<Parcel> scoped = parcels.where((final Parcel p) {
      if (scope == ExportScope.addedOnly && !p.isFieldAdded) return false;
      if (basinFilter != null && p.basinName != basinFilter) return false;
      return true;
    }).toList();

    if (scoped.isEmpty) return null;

    final xlsx.Excel workbook = xlsx.Excel.createExcel();

    final xlsx.Sheet allSheet = workbook[_allDataSheetName];
    _writeHeader(allSheet);
    for (final Parcel p in scoped) {
      allSheet.appendRow(_rowFor(p));
    }

    final Map<String, List<Parcel>> byBasin = <String, List<Parcel>>{};
    for (final Parcel p in scoped) {
      final String? basin = p.basinName?.trim();
      if (basin == null || basin.isEmpty) continue;
      byBasin.putIfAbsent(basin, () => <Parcel>[]).add(p);
    }
    for (final MapEntry<String, List<Parcel>> entry in byBasin.entries) {
      final xlsx.Sheet basinSheet = workbook[entry.key];
      _writeHeader(basinSheet);
      for (final Parcel p in entry.value) {
        basinSheet.appendRow(_rowFor(p));
      }
    }

    // `Excel.createExcel()` starts with one default empty sheet — drop it
    // now that the real sheets are in, so the output file doesn't carry a
    // stray blank tab.
    final String? defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null &&
        defaultSheet != _allDataSheetName &&
        !byBasin.containsKey(defaultSheet)) {
      workbook.delete(defaultSheet);
    }

    final List<int>? bytes = workbook.save();
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  /// Builds the shared filename for an export — association name + basin
  /// scope + data scope, so a field worker sharing several exports from the
  /// same phone can tell them apart without opening each one (UI/UX Updates
  /// prompt "Change 2"). `associationName` is cleaned for filesystem safety
  /// (`-`/spaces → `_`); `basinName` of `null`/empty means "every basin".
  static String buildExportFileName({
    required final String associationName,
    required final String? basinName,
    required final ExportScope scope,
  }) {
    final String cleanName =
        associationName.replaceAll('-', '_').replaceAll(' ', '_').trim();

    final String basinPart = (basinName == null || basinName.trim().isEmpty)
        ? 'كل_الاحواض'
        : basinName.trim().replaceAll(' ', '_');

    final String scopePart =
        scope == ExportScope.addedOnly ? '_بيانات_مضافة' : '';

    return '${cleanName}_$basinPart$scopePart.xlsx';
  }

  void _writeHeader(final xlsx.Sheet sheet) {
    sheet.appendRow(
      columns.map((final String c) => xlsx.TextCellValue(c)).toList(),
    );
  }

  List<xlsx.CellValue> _rowFor(final Parcel p) {
    String text(final String? value) => value?.trim().isNotEmpty ?? false ? value!.trim() : '-';
    xlsx.CellValue cell(final String? value) => xlsx.TextCellValue(text(value));
    xlsx.CellValue numberCell(final double? value) =>
        value == null ? xlsx.TextCellValue('-') : xlsx.DoubleCellValue(value);

    return <xlsx.CellValue>[
      cell(p.id),
      cell(p.holdingId),
      cell(p.associationName),
      cell(p.creditType),
      cell(_formatter.displayOwnerName(p)),
      cell(p.nationalId),
      cell(_formatter.displayHolderName(p)),
      cell(p.landNumber),
      numberCell(p.feddan),
      numberCell(p.qirat),
      numberCell(p.sahm),
      cell(p.basinCode == null ? p.basinName : '${p.basinCode} - ${p.basinName ?? ''}'),
      cell(p.usageType),
      cell(p.cropType),
      cell(p.growthStages),
      cell(p.notes.isEmpty ? null : p.notes.join('، ')),
    ];
  }
}
