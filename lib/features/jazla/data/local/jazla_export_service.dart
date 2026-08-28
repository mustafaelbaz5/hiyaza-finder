import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;

import '../../../holdings/data/local/clipboard_formatter.dart';
import '../../../holdings/data/model/parcel.dart';

/// Builds a Jazla's .xlsx export — separate from `holdings/export_service.dart`
/// (different columns/scope model). التسلسل reflects the Jazla's own order,
/// not any holding grouping.
class JazlaExportService {
  const JazlaExportService({
    final ClipboardFormatter formatter = const ClipboardFormatter(),
  }) : _formatter = formatter;

  final ClipboardFormatter _formatter;

  static const List<String> columns = <String>[
    'التسلسل',
    'اسم الحائز',
    'اسم المالك',
    'رقم الحيازة',
    'سهم',
    'قيراط',
    'فدان',
    'الملاحظات',
  ];

  Uint8List? export({
    required final String jazlaName,
    required final List<Parcel> orderedParcels,
  }) {
    if (orderedParcels.isEmpty) return null;

    final xlsx.Excel workbook = xlsx.Excel.createExcel();
    final xlsx.Sheet sheet = workbook[jazlaName];
    sheet.isRTL = true;

    sheet.appendRow(columns.map(xlsx.TextCellValue.new).toList());

    for (int i = 0; i < orderedParcels.length; i++) {
      final Parcel p = orderedParcels[i];
      sheet.appendRow(<xlsx.CellValue>[
        xlsx.IntCellValue(i + 1),
        xlsx.TextCellValue(_formatter.displayHolderName(p)),
        xlsx.TextCellValue(_formatter.displayOwnerName(p)),
        xlsx.TextCellValue(p.holdingId),
        p.sahm == null ? xlsx.TextCellValue('-') : xlsx.DoubleCellValue(p.sahm!),
        p.qirat == null ? xlsx.TextCellValue('-') : xlsx.DoubleCellValue(p.qirat!),
        p.feddan == null ? xlsx.TextCellValue('-') : xlsx.DoubleCellValue(p.feddan!),
        xlsx.TextCellValue(p.notes.isEmpty ? '-' : p.notes.join('، ')),
      ]);
    }

    final String? defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != jazlaName) {
      workbook.delete(defaultSheet);
    }

    final List<int>? bytes = workbook.save();
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  static String buildFileName(final String cityName, final String jazlaName) {
    final DateTime now = DateTime.now();
    final String dd = now.day.toString().padLeft(2, '0');
    final String mm = now.month.toString().padLeft(2, '0');
    final String cleanCity = cityName.replaceAll('-', '_').replaceAll(' ', '_').trim();
    final String cleanJazla = jazlaName.replaceAll('-', '_').replaceAll(' ', '_').trim();
    return '${cleanCity}_${cleanJazla}_${dd}_${mm}_${now.year}.xlsx';
  }
}
