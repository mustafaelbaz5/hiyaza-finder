import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiyaza_finder/features/cities/data/model/association_type.dart';
import 'package:hiyaza_finder/features/jazla/data/model/jazla.dart';
import 'package:hiyaza_finder/features/jazla/data/model/jazla_parcel_defaults.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/parcel_completion_store.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';
import 'package:hiyaza_finder/features/jazla_transfer/data/local/jazla_transfer_codec.dart';
import 'package:hiyaza_finder/features/jazla_transfer/data/local/jazla_transfer_matcher.dart';
import 'package:hiyaza_finder/features/jazla_transfer/data/model/jazla_transfer_bundle.dart';
import 'package:hiyaza_finder/features/jazla_transfer/data/model/jazla_transfer_manifest.dart';

void main() {
  const JazlaTransferCodec codec = JazlaTransferCodec();
  const Parcel parcelOne = Parcel(
    id: 'parcel-1',
    holdingId: '100',
    holderName: 'حسن محمد',
    associationName: 'جمعية الاختبار',
  );
  const Parcel parcelTwo = Parcel(
    id: 'parcel-2',
    holdingId: '200',
    holderName: 'علي محمد',
    associationName: 'جمعية الاختبار',
  );

  JazlaTransferBundle bundle() => JazlaTransferBundle(
        manifest: JazlaTransferManifest(
          schemaVersion: 1,
          bundleType: JazlaTransferCodec.bundleType,
          exportedAt: DateTime(2026, 9, 30),
          sourceAppVersion: '1.1.9',
          cityId: 'city-1',
          cityName: 'مدينة الاختبار',
          association: const JazlaTransferAssociation(
            name: 'جمعية الاختبار',
            code: '123',
            type: AssociationType.agriculturalCredit,
          ),
        ),
        jazla: Jazla(
          id: 'jazla-1',
          cityId: 'city-1',
          name: 'جزلة سبتمبر',
          parcelIds: const <String>['parcel-2', 'parcel-1'],
          parcelDefaults: const JazlaParcelDefaults(cropType: 'قمح'),
          createdAt: DateTime(2026, 9, 30),
        ),
        parcels: <Parcel>[parcelTwo, parcelOne],
        completionStatuses: <String, ParcelCompletionStatus>{
          'parcel-2': ParcelCompletionStatus(
            completedAt: DateTime(2026, 9, 30, 10),
          ),
        },
      );

  test('round trip preserves Jazla order, parcel values, defaults, and review',
      () {
    final JazlaTransferBundle decoded = codec.decode(codec.encode(bundle()));

    expect(decoded.jazla.parcelIds, <String>['parcel-2', 'parcel-1']);
    expect(decoded.parcels.map((final Parcel parcel) => parcel.id),
        <String>['parcel-2', 'parcel-1']);
    expect(decoded.jazla.parcelDefaults?.cropType, 'قمح');
    expect(decoded.completionStatuses['parcel-2']?.completedAt,
        DateTime(2026, 9, 30, 10));
  });

  test('rejects duplicate parcel ids and unknown Jazla references', () {
    final Map<String, dynamic> json = bundle().toJson();
    json['parcels'] = <Map<String, dynamic>>[
      parcelOne.toJson(),
      parcelOne.toJson(),
    ];
    expect(() => codec.decode(_encode(json)), throwsFormatException);
  });

  test('matches the exact city and normalized association identity', () {
    const JazlaTransferMatcher matcher = JazlaTransferMatcher();
    final JazlaTransferManifest manifest = bundle().manifest;

    expect(
      matcher.mismatch(
        manifest: manifest,
        cityId: 'city-1',
        cityName: 'مدينة الاختبار',
        associationName: 'جمعية الاختبار',
        associationCode: '123',
        associationType: AssociationType.agriculturalCredit,
      ),
      isNull,
    );
    expect(
      matcher.mismatch(
        manifest: manifest,
        cityId: 'city-2',
        cityName: 'مدينة الاختبار',
        associationName: 'جمعية الاختبار',
        associationCode: '123',
        associationType: AssociationType.agriculturalCredit,
      ),
      'jazla.transfer.error_city_mismatch',
    );
    expect(
      matcher.mismatch(
        manifest: manifest,
        cityId: 'city-1',
        cityName: 'مدينة الاختبار',
        associationName: 'جمعية مختلفة',
        associationCode: '123',
        associationType: AssociationType.agriculturalCredit,
      ),
      'jazla.transfer.error_association_mismatch',
    );
  });
}

String _encode(final Map<String, dynamic> value) {
  // This test only needs to feed a JSON-shaped map back to the codec.
  return jsonEncode(value);
}
