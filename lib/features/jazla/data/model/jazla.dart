import 'package:equatable/equatable.dart';

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
    required this.createdAt,
  });

  final String id;
  final String cityId;
  final String name;

  /// Insertion/display order — reordering rewrites this list wholesale.
  final List<String> parcelIds;
  final DateTime createdAt;

  int get parcelCount => parcelIds.length;

  Jazla copyWith({
    final String? name,
    final List<String>? parcelIds,
  }) =>
      Jazla(
        id: id,
        cityId: cityId,
        name: name ?? this.name,
        parcelIds: parcelIds ?? this.parcelIds,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cityId': cityId,
        'name': name,
        'parcelIds': parcelIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Jazla.fromJson(final Map<String, dynamic> json) => Jazla(
        id: json['id'] as String,
        cityId: json['cityId'] as String,
        name: json['name'] as String,
        parcelIds: (json['parcelIds'] as List<dynamic>).cast<String>(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => <Object?>[id, cityId, name, parcelIds, createdAt];
}
