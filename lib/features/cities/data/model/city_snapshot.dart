
import '../../../holdings/data/model/parcel.dart';

import 'association_type.dart';

/// A downloaded-and-cached city dataset — what the app actually works
/// from offline once a city has been picked. [dataVersion] is what the
/// staleness check compares against the server's current
/// `cities.data_version`. [associationType]/[associationSubtype] are
/// copied straight from the `City` row at download time (the DB is the
/// single source of truth — no per-parcel detection) and cached here so
/// they survive an offline reload without needing a fresh `cities` query.
class CitySnapshot {
  const CitySnapshot({
    required this.cityId,
    required this.cityName,
    required this.dataVersion,
    required this.downloadedAt,
    required this.parcels,
    this.directorate,
    this.administration,
    this.associationType,
    this.associationSubtype,
  });

  final String cityId;
  final String cityName;
  final int dataVersion;
  final DateTime downloadedAt;
  final List<Parcel> parcels;

  /// Carried forward so `HomeCubit.refreshActiveCity` can reconstruct a
  /// full `City` for re-download without a value going missing on refresh.
  final String? directorate;
  final String? administration;

  final AssociationType? associationType;
  final String? associationSubtype;
}
