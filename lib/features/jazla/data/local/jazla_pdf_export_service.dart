import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../holdings/data/local/area_calculator.dart';
import '../../../holdings/data/model/parcel.dart';
import '../model/jazla.dart';

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
    final double addedArea = parcels.fold<double>(
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
    final double? targetArea = jazla.targetAreaSqm;
    final double? difference =
        targetArea == null ? null : targetArea - addedArea;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        textDirection: pw.TextDirection.rtl,
        build: (final pw.Context context) => [
          pw.Text('تفاصيل الجزلة',
              style: pw.TextStyle(font: bold, fontSize: 20)),
          pw.SizedBox(height: 12),
          _summaryTable(
              jazla, addedArea, targetArea, difference, regular, bold),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: const <String>[
              'التسلسل',
              'اسم الحائز',
              'اسم المالك',
              'رقم الحيازة',
              'المساحة بالمتر المربع',
            ],
            data: [
              for (int i = 0; i < parcels.length; i++)
                <String>[
                  '${i + 1}',
                  parcels[i].holderName ?? '-',
                  parcels[i].ownerName ?? '-',
                  parcels[i].holdingId,
                  _parcelArea(parcels[i]),
                ],
            ],
            headerStyle: pw.TextStyle(font: bold, fontSize: 9),
            cellStyle: pw.TextStyle(font: regular, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green200),
            cellAlignment: pw.Alignment.centerRight,
            border: pw.TableBorder.all(color: PdfColors.grey400),
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _summaryTable(
    final Jazla jazla,
    final double added,
    final double? target,
    final double? difference,
    final pw.Font regular,
    final pw.Font bold,
  ) =>
      pw.TableHelper.fromTextArray(
        data: <List<String>>[
          <String>['اسم الجزلة', jazla.name],
          <String>['الحوض', jazla.basinName ?? '-'],
          <String>['المساحة المضافة (م²)', _format(added)],
          <String>[
            'المساحة المستهدفة (م²)',
            target == null ? '-' : _format(target)
          ],
          <String>[
            'الفرق (م²)',
            difference == null ? '-' : _format(difference.abs())
          ],
        ],
        cellStyle: pw.TextStyle(font: regular, fontSize: 10),
        border: pw.TableBorder.all(color: PdfColors.grey400),
      );

  String _parcelArea(final Parcel parcel) {
    final double? value = AreaCalculator.totalSqm(
      feddan: parcel.feddan,
      qirat: parcel.qirat,
      sahm: parcel.sahm,
    );
    return value == null ? 'المساحة غير محددة' : _format(value);
  }

  String _format(final double value) => value.toStringAsFixed(2);
}
