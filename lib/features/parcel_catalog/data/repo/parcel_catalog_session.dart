import '../../../cities/data/model/association_type.dart';
import '../../../cities/data/model/basin.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

/// Write-side boundary for replacing the active city dataset.
///
/// A screen/cubit that starts a city session should not receive the broad
/// holdings implementation merely to adopt a cached snapshot. Reads and
/// parcel mutations stay behind their narrower contracts.
abstract class ParcelCatalogSession {
  Future<List<Parcel>> loadParcelsForCity(
    final String cityId,
    final List<Parcel> parcels, {
    final String? cityName,
    final String? directorate,
    final String? administration,
    final AssociationType? associationType,
    final String? associationSubtype,
    final List<Basin> basins,
  });
}
