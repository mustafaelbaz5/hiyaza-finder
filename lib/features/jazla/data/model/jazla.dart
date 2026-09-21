import 'package:equatable/equatable.dart';

import '../../../holdings/data/local/area_calculator.dart';

/// A local, non-data-owning grouping of parcel IDs (الجزلة) — an organizer,
/// not a second source of truth. Holds `parcelIds` only; the actual [Parcel]
/// data always lives in and is read/written through `HoldingsRepository`.
/// Scoped per city — never shared across [cityId]s.
class Jazla extends Equatable {
  const Jazla({
    required this.id,
    required this.cityId,
    required this.name,
    this.parcelIds = const <String>[],
    this.targetFeddan,
    this.targetQirat,
    this.targetSahm,
    this.targetAreaSqmOverride,
    required this.createdAt,
  });

  final String id;
  final String cityId;
  final String name;

  /// Insertion/display order — reordering rewrites this list wholesale.
  final List<String> parcelIds;
  final double? targetFeddan;
  final double? targetQirat;
  final double? targetSahm;
  final double? targetAreaSqmOverride;
  final DateTime createdAt;

  int get parcelCount => parcelIds.length;

  double? get targetAreaSqm =>
      targetAreaSqmOverride ??
      AreaCalculator.totalSqm(
        feddan: targetFeddan,
        qirat: targetQirat,
        sahm: targetSahm,
      );

  Jazla copyWith({
    final String? name,
    final List<String>? parcelIds,
    final double? targetFeddan,
    final double? targetQirat,
    final double? targetSahm,
    final double? targetAreaSqmOverride,
  }) =>
      Jazla(
        id: id,
        cityId: cityId,
        name: name ?? this.name,
        parcelIds: parcelIds ?? this.parcelIds,
        targetFeddan: targetFeddan ?? this.targetFeddan,
        targetQirat: targetQirat ?? this.targetQirat,
        targetSahm: targetSahm ?? this.targetSahm,
        targetAreaSqmOverride:
            targetAreaSqmOverride ?? this.targetAreaSqmOverride,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cityId': cityId,
        'name': name,
        'parcelIds': parcelIds,
        'targetFeddan': targetFeddan,
        'targetQirat': targetQirat,
        'targetSahm': targetSahm,
        'targetAreaSqm': targetAreaSqmOverride,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Jazla.fromJson(final Map<String, dynamic> json) => Jazla(
        id: json['id'] as String,
        cityId: json['cityId'] as String,
        name: json['name'] as String,
        parcelIds: (json['parcelIds'] as List<dynamic>).cast<String>(),
        targetFeddan: (json['targetFeddan'] as num?)?.toDouble(),
        targetQirat: (json['targetQirat'] as num?)?.toDouble(),
        targetSahm: (json['targetSahm'] as num?)?.toDouble(),
        targetAreaSqmOverride: (json['targetAreaSqm'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        cityId,
        name,
        parcelIds,
        targetFeddan,
        targetQirat,
        targetSahm,
        targetAreaSqmOverride,
        createdAt,
      ];
}
