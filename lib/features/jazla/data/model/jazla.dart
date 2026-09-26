import 'package:equatable/equatable.dart';

import 'package:hiyaza_finder/features/parcel_catalog/data/local/area_calculator.dart';

/// A local, non-data-owning grouping of parcel IDs (الجزلة) — an organizer,
/// not a second source of truth. Holds `parcelIds` only; the actual [Parcel]
/// data always lives in and is read/written through `ParcelCatalogRepository`.
/// Scoped per city — never shared across [cityId]s.
class Jazla extends Equatable {
  const Jazla({
    required this.id,
    required this.cityId,
    required this.name,
    this.basinName,
    this.parcelIds = const <String>[],
    this.targetFeddan,
    this.targetQirat,
    this.targetSahm,
    this.targetAreaSqmOverride,
    required this.createdAt,
    final DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final String cityId;
  final String name;
  final String? basinName;

  /// Insertion/display order — reordering rewrites this list wholesale.
  final List<String> parcelIds;
  final double? targetFeddan;
  final double? targetQirat;
  final double? targetSahm;
  final double? targetAreaSqmOverride;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    final String? basinName,
    final List<String>? parcelIds,
    final double? targetFeddan,
    final double? targetQirat,
    final double? targetSahm,
    final double? targetAreaSqmOverride,
    final DateTime? updatedAt,
  }) =>
      Jazla(
        id: id,
        cityId: cityId,
        name: name ?? this.name,
        basinName: basinName ?? this.basinName,
        parcelIds: parcelIds ?? this.parcelIds,
        targetFeddan: targetFeddan ?? this.targetFeddan,
        targetQirat: targetQirat ?? this.targetQirat,
        targetSahm: targetSahm ?? this.targetSahm,
        targetAreaSqmOverride:
            targetAreaSqmOverride ?? this.targetAreaSqmOverride,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cityId': cityId,
        'name': name,
        'basinName': basinName,
        'parcelIds': parcelIds,
        'targetFeddan': targetFeddan,
        'targetQirat': targetQirat,
        'targetSahm': targetSahm,
        'targetAreaSqm': targetAreaSqmOverride,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Jazla.fromJson(final Map<String, dynamic> json) => Jazla(
        id: json['id'] as String,
        cityId: json['cityId'] as String,
        name: json['name'] as String,
        basinName: json['basinName'] as String?,
        parcelIds: (json['parcelIds'] as List<dynamic>).cast<String>(),
        targetFeddan: (json['targetFeddan'] as num?)?.toDouble(),
        targetQirat: (json['targetQirat'] as num?)?.toDouble(),
        targetSahm: (json['targetSahm'] as num?)?.toDouble(),
        targetAreaSqmOverride: (json['targetAreaSqm'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.parse(json['updatedAt'] as String),
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        cityId,
        name,
        basinName,
        parcelIds,
        targetFeddan,
        targetQirat,
        targetSahm,
        targetAreaSqmOverride,
        createdAt,
        updatedAt,
      ];
}
