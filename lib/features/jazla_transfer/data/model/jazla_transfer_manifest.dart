import 'package:hiyaza_finder/features/cities/data/model/association_type.dart';

class JazlaTransferAssociation {
  const JazlaTransferAssociation({
    required this.name,
    required this.type,
    this.code,
  });

  final String name;
  final String? code;
  final AssociationType type;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'name': name,
        'type': associationTypeToString(type),
      };

  factory JazlaTransferAssociation.fromJson(final Map<String, dynamic> json) {
    final String? rawType = json['type'] as String?;
    final AssociationType? type = associationTypeFromString(rawType);
    final String name = json['name'] as String? ?? '';
    if (type == null || name.trim().isEmpty) {
      throw const FormatException('Invalid association metadata.');
    }
    return JazlaTransferAssociation(
      name: name.trim(),
      code: (json['code'] as String?)?.trim(),
      type: type,
    );
  }
}

class JazlaTransferManifest {
  const JazlaTransferManifest({
    required this.schemaVersion,
    required this.bundleType,
    required this.exportedAt,
    required this.sourceAppVersion,
    required this.cityId,
    required this.cityName,
    required this.association,
  });

  final int schemaVersion;
  final String bundleType;
  final DateTime exportedAt;
  final String sourceAppVersion;
  final String cityId;
  final String cityName;
  final JazlaTransferAssociation association;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'bundleType': bundleType,
        'exportedAt': exportedAt.toIso8601String(),
        'sourceAppVersion': sourceAppVersion,
        'source': <String, dynamic>{
          'city': <String, dynamic>{'id': cityId, 'name': cityName},
          'association': association.toJson(),
        },
      };
}
