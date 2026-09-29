import '../model/parcel.dart';
import '../model/parcel_activity_summary.dart';
import '../model/parcel_visibility_filter.dart';
import 'parcel_activity_classifier.dart';

/// Immutable activity indexes built once whenever the active catalog changes.
class ParcelActivityIndex {
  ParcelActivityIndex._({
    required this.all,
    required this.active,
    required this.zeroArea,
    required this.summary,
    required final Map<String, ParcelActivitySummary> basinSummaries,
  }) : _basinSummaries = basinSummaries;

  factory ParcelActivityIndex.build(
    final List<Parcel> parcels, {
    final ParcelActivityClassifier classifier =
        const ParcelActivityClassifier(),
  }) {
    final List<Parcel> active = <Parcel>[];
    final List<Parcel> zeroArea = <Parcel>[];
    final Map<String, _MutableSummary> byBasin = <String, _MutableSummary>{};

    for (final Parcel parcel in parcels) {
      final bool isActive = classifier.isActive(parcel);
      (isActive ? active : zeroArea).add(parcel);

      final String? basinName = parcel.basinName?.trim();
      if (basinName != null && basinName.isNotEmpty) {
        final _MutableSummary basin =
            byBasin.putIfAbsent(basinName, _MutableSummary.new);
        basin.total += 1;
        if (isActive) {
          basin.active += 1;
        } else {
          basin.zeroArea += 1;
        }
      }
    }

    return ParcelActivityIndex._(
      all: List<Parcel>.unmodifiable(parcels),
      active: List<Parcel>.unmodifiable(active),
      zeroArea: List<Parcel>.unmodifiable(zeroArea),
      summary: ParcelActivitySummary(
        totalParcelCount: parcels.length,
        activeParcelCount: active.length,
        zeroAreaParcelCount: zeroArea.length,
      ),
      basinSummaries: Map<String, ParcelActivitySummary>.unmodifiable(
        byBasin.map(
          (final String name, final _MutableSummary value) => MapEntry(
            name,
            ParcelActivitySummary(
              totalParcelCount: value.total,
              activeParcelCount: value.active,
              zeroAreaParcelCount: value.zeroArea,
            ),
          ),
        ),
      ),
    );
  }

  final List<Parcel> all;
  final List<Parcel> active;
  final List<Parcel> zeroArea;
  final ParcelActivitySummary summary;
  final Map<String, ParcelActivitySummary> _basinSummaries;

  List<Parcel> parcelsFor(
    final ParcelVisibilityFilter filter, {
    final String? basinName,
  }) {
    final List<Parcel> source = switch (filter) {
      ParcelVisibilityFilter.activeOnly => active,
      ParcelVisibilityFilter.all => all,
      ParcelVisibilityFilter.zeroAreaOnly => zeroArea,
    };
    if (basinName == null) return source;
    return List<Parcel>.unmodifiable(
      source.where((final Parcel parcel) => parcel.basinName == basinName),
    );
  }

  ParcelActivitySummary summaryForBasin(final String basinName) =>
      _basinSummaries[basinName] ?? const ParcelActivitySummary();
}

class _MutableSummary {
  int total = 0;
  int active = 0;
  int zeroArea = 0;
}
