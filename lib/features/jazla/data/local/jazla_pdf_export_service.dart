import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../parcel_catalog/data/local/area_calculator.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../model/jazla.dart';

/// A compact, landscape printable report. Excel retains the more detailed
/// operational data; this document favors fast field review and sharing.
class JazlaPdfExportService {
  const JazlaPdfExportService();

  Future<Uint8List> export({
    required final Jazla jazla,
    required final List<Parcel> parcels,
  }) async {
    final pw.Document document = pw.Document();
    final pw.Font regular = pw.Font.ttf(
      (await rootBundle.load('assets/fonts/tajawal/Tajawal-Regular.ttf')),
    );
    final pw.Font bold = pw.Font.ttf(
      (await rootBundle.load('assets/fonts/tajawal/Tajawal-Bold.ttf')),
    );
    final double addedArea = _addedArea(parcels);
    final double? targetArea = jazla.targetAreaSqm;
    final double? difference =
        targetArea == null ? null : targetArea - addedArea;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 22),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        textDirection: pw.TextDirection.rtl,
        header: (final pw.Context context) => _pageHeader(jazla, bold),
        footer: (final pw.Context context) => pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(
                font: regular, fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (final pw.Context context) => <pw.Widget>[
          _summaryTable(
            jazla: jazla,
            parcelCount: parcels.length,
            added: addedArea,
            target: targetArea,
            difference: difference,
            regular: regular,
            bold: bold,
          ),
          pw.SizedBox(height: 16),
          _parcelTable(parcels, regular, bold),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _pageHeader(final Jazla jazla, final pw.Font bold) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.green700)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('تقرير الجزلة',
                    style: pw.TextStyle(font: bold, fontSize: 18)),
                pw.SizedBox(height: 2),
                pw.Text(jazla.name,
                    style: pw.TextStyle(font: bold, fontSize: 13)),
              ],
            ),
            pw.Text(
              _dateLabel(DateTime.now()),
              textDirection: pw.TextDirection.ltr,
              style: pw.TextStyle(
                  font: bold, fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
      );

  pw.Widget _summaryTable({
    required final Jazla jazla,
    required final int parcelCount,
    required final double added,
    required final double? target,
    required final double? difference,
    required final pw.Font regular,
    required final pw.Font bold,
  }) {
    final _PdfAreaStatus status = _PdfAreaStatus.fromDifference(difference);
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.TableHelper.fromTextArray(
        cellAlignment: pw.Alignment.centerRight,
        cellStyle: pw.TextStyle(font: regular, fontSize: 9),
        headerStyle:
            pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .4),
        headers: const <String>[
          'الحوض',
          'عدد القطع',
          'المساحة المستهدفة',
          'المساحة المضافة',
          'الفرق',
          'الحالة',
        ],
        data: <List<String>>[
          <String>[
            jazla.basinName ?? '—',
            '$parcelCount',
            target == null ? '—' : _formatArea(target),
            _formatArea(added),
            difference == null ? '—' : _formatArea(difference.abs()),
            status.label,
          ],
        ],
      ),
    );
  }

  pw.Widget _parcelTable(
    final List<Parcel> parcels,
    final pw.Font regular,
    final pw.Font bold,
  ) {
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerRight,
      cellStyle: pw.TextStyle(font: regular, fontSize: 7.5),
      headerStyle:
          pw.TextStyle(font: bold, fontSize: 8, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      border: pw.TableBorder.all(color: PdfColors.grey400, width: .35),
      headers: const <String>[
        'م',
        'كود القطعة',
        'اسم الحائز',
        'رقم الحيازة',
        'فدان / قيراط / سهم',
        'م²',
        'الملاحظات',
      ],
      data: <List<String>>[
        for (int index = 0; index < parcels.length; index++)
          <String>[
            '${index + 1}',
            _parcelCode(parcels[index].id),
            _text(parcels[index].holderName),
            _text(parcels[index].holdingId),
            _agriculturalArea(parcels[index]),
            _parcelArea(parcels[index]),
            parcels[index].notes.isEmpty
                ? '—'
                : parcels[index].notes.join('، '),
          ],
      ],
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FixedColumnWidth(22),
        1: pw.FixedColumnWidth(78),
        2: pw.FlexColumnWidth(1.35),
        3: pw.FixedColumnWidth(62),
        4: pw.FixedColumnWidth(94),
        5: pw.FixedColumnWidth(46),
        6: pw.FlexColumnWidth(1.5),
      },
    );
  }

  static double _addedArea(final List<Parcel> parcels) => parcels.fold<double>(
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

  static String _parcelCode(final String value) {
    if (value.trim().isEmpty) return '—';
    return value.length <= 12 ? value : '${value.substring(0, 8)}…';
  }

  static String _text(final String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '—' : normalized;
  }

  static String _agriculturalArea(final Parcel parcel) {
    if (parcel.feddan == null && parcel.qirat == null && parcel.sahm == null) {
      return '—';
    }
    return '${_number(parcel.feddan)} / ${_number(parcel.qirat)} / ${_number(parcel.sahm)}';
  }

  static String _parcelArea(final Parcel parcel) {
    final double? value = AreaCalculator.totalSqm(
      feddan: parcel.feddan,
      qirat: parcel.qirat,
      sahm: parcel.sahm,
    );
    return value == null ? '—' : _formatArea(value);
  }

  static String _number(final double? value) => value == null
      ? '—'
      : value == value.roundToDouble()
          ? '${value.toInt()}'
          : '$value';

  static String _formatArea(final double value) => value.toStringAsFixed(2);

  static String _dateLabel(final DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _PdfAreaStatus {
  const _PdfAreaStatus._(this.label);

  final String label;

  static _PdfAreaStatus fromDifference(final double? difference) {
    if (difference == null) return const _PdfAreaStatus._('غير محدد');
    if (difference.abs() < 0.01) return const _PdfAreaStatus._('مطابق');
    if (difference < 0) return const _PdfAreaStatus._('متجاوز');
    return const _PdfAreaStatus._('متبقي');
  }
}
