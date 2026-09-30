import 'dart:typed_data';

import '../../../cities/data/model/association_type.dart';
import '../../../jazla/data/model/jazla.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../model/jazla_transfer_bundle.dart';

abstract class JazlaTransferRepository {
  Future<JazlaTransferBundle> buildExport({
    required final Jazla jazla,
    required final List<Parcel> orderedParcels,
    required final String cityId,
    required final String cityName,
    required final String associationName,
    required final String? associationCode,
    required final AssociationType associationType,
  });

  Future<JazlaTransferBundle> readFile();
  Future<void> importBundle(
    final JazlaTransferBundle bundle, {
    required final bool replace,
  });
  Future<Uint8List> encode(final JazlaTransferBundle bundle);
  Future<List<Parcel>> loadFallback(final String cityId, final String jazlaId);
}
