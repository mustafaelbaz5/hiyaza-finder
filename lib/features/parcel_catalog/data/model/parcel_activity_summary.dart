import 'package:equatable/equatable.dart';

/// Cached operational counts for a parcel scope such as a city or basin.
class ParcelActivitySummary extends Equatable {
  const ParcelActivitySummary({
    this.totalParcelCount = 0,
    this.activeParcelCount = 0,
    this.zeroAreaParcelCount = 0,
  });

  final int totalParcelCount;
  final int activeParcelCount;
  final int zeroAreaParcelCount;

  @override
  List<Object?> get props => <Object?>[
        totalParcelCount,
        activeParcelCount,
        zeroAreaParcelCount,
      ];
}
