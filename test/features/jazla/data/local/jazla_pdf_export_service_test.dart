import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/jazla/data/local/jazla_pdf_export_service.dart';
import 'package:hiyaza_finder/features/jazla/data/model/jazla.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compact report creates a valid PDF for Jazla parcels', () async {
    final bytes = await const JazlaPdfExportService().export(
      jazla: Jazla(
        id: 'jazla-1',
        cityId: 'city-1',
        name: 'جزلة الري',
        basinName: 'حوض النيل',
        targetAreaSqmOverride: 1000,
        createdAt: DateTime.utc(2026),
      ),
      parcels: const <Parcel>[
        Parcel(
          id: 'parcel-1',
          holdingId: '12',
          holderName: 'محمد أحمد',
          feddan: 1,
          qirat: 2,
          sahm: 3,
          notes: <String>['مراجعة ميدانية'],
        ),
      ],
    );

    expect(bytes, isNotEmpty);
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
  });
}
