import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/parcel_activity_classifier.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/parcel_activity_index.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel_activity_status.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel_visibility_filter.dart';

void main() {
  const ParcelActivityClassifier classifier = ParcelActivityClassifier();

  test(
      'zero agricultural units remain a zero-area record even with missing borders',
      () {
    const Parcel parcel = Parcel(
      id: 'zero',
      holdingId: '1',
      feddan: 0,
      qirat: 0,
      sahm: 0,
    );

    expect(classifier.classify(parcel), ParcelActivityStatus.zeroArea);
  });

  test('a positive agricultural unit makes the record active', () {
    const Parcel parcel = Parcel(
      id: 'active',
      holdingId: '2',
      feddan: 0,
      qirat: 1,
      sahm: 0,
    );

    expect(classifier.classify(parcel), ParcelActivityStatus.active);
  });

  test('index separates visibility scopes and keeps per-basin counts', () {
    final ParcelActivityIndex index = ParcelActivityIndex.build(<Parcel>[
      const Parcel(id: 'a', holdingId: '1', basinName: 'أ', feddan: 1),
      const Parcel(id: 'z', holdingId: '2', basinName: 'أ'),
      const Parcel(id: 'b', holdingId: '3', basinName: 'ب', sahm: 1),
    ]);

    expect(index.summary.activeParcelCount, 2);
    expect(index.summary.zeroAreaParcelCount, 1);
    expect(index.parcelsFor(ParcelVisibilityFilter.activeOnly), hasLength(2));
    expect(index.parcelsFor(ParcelVisibilityFilter.zeroAreaOnly), hasLength(1));
    expect(index.summaryForBasin('أ').activeParcelCount, 1);
    expect(index.summaryForBasin('أ').zeroAreaParcelCount, 1);
  });
}
