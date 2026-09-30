import 'dart:convert';

import '../../../jazla/data/model/jazla.dart';
import '../../../parcel_catalog/data/local/parcel_completion_store.dart';
import '../../../parcel_catalog/data/model/parcel.dart';
import '../model/jazla_transfer_bundle.dart';
import '../model/jazla_transfer_manifest.dart';

class JazlaTransferCodec {
  const JazlaTransferCodec();

  static const int supportedSchemaVersion = 1;
  static const String bundleType = 'jazla_transfer';
  static const int maxParcelCount = 5000;
  static const int maxBytes = 10 * 1024 * 1024;

  String encode(final JazlaTransferBundle bundle) =>
      jsonEncode(bundle.toJson());

  JazlaTransferBundle decode(final String raw) {
    final List<int> bytes = utf8.encode(raw);
    if (bytes.length > maxBytes) {
      throw const FormatException('Transfer file is too large.');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('Transfer file is not valid JSON.');
    }
    if (decoded is! Map) {
      throw const FormatException('Transfer file must contain an object.');
    }
    return _decodeMap(decoded.cast<String, dynamic>());
  }

  JazlaTransferBundle _decodeMap(final Map<String, dynamic> json) {
    if (json['bundleType'] != bundleType) {
      throw const FormatException('Unsupported transfer file type.');
    }
    if (json['schemaVersion'] != supportedSchemaVersion) {
      throw const FormatException('Unsupported transfer file version.');
    }
    final Map<String, dynamic> source = _map(json['source']);
    final Map<String, dynamic> city = _map(source['city']);
    final String cityId = city['id'] as String? ?? '';
    final String cityName = city['name'] as String? ?? '';
    final DateTime? exportedAt =
        DateTime.tryParse(json['exportedAt'] as String? ?? '');
    if (cityId.isEmpty || cityName.trim().isEmpty || exportedAt == null) {
      throw const FormatException('Incomplete transfer manifest.');
    }

    final JazlaTransferManifest manifest = JazlaTransferManifest(
      schemaVersion: supportedSchemaVersion,
      bundleType: bundleType,
      exportedAt: exportedAt,
      sourceAppVersion: json['sourceAppVersion'] as String? ?? 'unknown',
      cityId: cityId,
      cityName: cityName.trim(),
      association:
          JazlaTransferAssociation.fromJson(_map(source['association'])),
    );
    final dynamic jazlaRaw = json['jazla'];
    final Jazla jazla = Jazla.fromJson(_map(jazlaRaw));
    if (jazla.cityId != cityId) {
      throw const FormatException('Jazla city does not match the manifest.');
    }
    final dynamic parcelsRaw = json['parcels'];
    if (parcelsRaw is! List || parcelsRaw.length > maxParcelCount) {
      throw const FormatException('Invalid or oversized parcel list.');
    }
    final List<Parcel> parcels = parcelsRaw
        .map((final dynamic value) => Parcel.fromJson(_map(value)))
        .toList();
    final Set<String> parcelIds = <String>{};
    for (final Parcel parcel in parcels) {
      if (parcel.id.trim().isEmpty || !parcelIds.add(parcel.id)) {
        throw const FormatException('Parcel IDs must be unique and non-empty.');
      }
    }
    if (jazla.parcelIds.length != jazla.parcelIds.toSet().length ||
        jazla.parcelIds.any((final String id) => !parcelIds.contains(id))) {
      throw const FormatException('Jazla parcel references are invalid.');
    }
    final Map<String, ParcelCompletionStatus> statuses =
        <String, ParcelCompletionStatus>{};
    final dynamic statusesRaw =
        json['completionStatuses'] ?? <String, dynamic>{};
    final Map<String, dynamic> statusMap = _map(statusesRaw);
    for (final MapEntry<String, dynamic> entry in statusMap.entries) {
      if (!parcelIds.contains(entry.key)) {
        throw const FormatException(
            'Completion status references an unknown parcel.');
      }
      final ParcelCompletionStatus? status =
          ParcelCompletionStatus.fromJson(entry.value);
      if (status == null) {
        throw const FormatException('Invalid completion status.');
      }
      statuses[entry.key] = status;
    }
    return JazlaTransferBundle(
      manifest: manifest,
      jazla: jazla,
      parcels: List<Parcel>.unmodifiable(parcels),
      completionStatuses:
          Map<String, ParcelCompletionStatus>.unmodifiable(statuses),
    );
  }

  static Map<String, dynamic> _map(final dynamic value) {
    if (value is! Map) throw const FormatException('Invalid transfer object.');
    return value.cast<String, dynamic>();
  }
}
