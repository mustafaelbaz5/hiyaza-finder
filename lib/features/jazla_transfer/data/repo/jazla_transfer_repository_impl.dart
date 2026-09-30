import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hiyaza_finder/core/config/app_config.dart';
import 'package:hiyaza_finder/features/cities/data/model/association_type.dart';
import 'package:hiyaza_finder/features/jazla/data/local/jazla_store.dart';
import 'package:hiyaza_finder/features/jazla/data/model/jazla.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/local/parcel_completion_store.dart';
import 'package:hiyaza_finder/features/parcel_catalog/data/model/parcel.dart';

import '../local/imported_jazla_parcel_store.dart';
import '../local/jazla_transfer_codec.dart';
import '../model/jazla_transfer_bundle.dart';
import '../model/jazla_transfer_manifest.dart';
import 'jazla_transfer_repository.dart';

class JazlaTransferRepositoryImpl implements JazlaTransferRepository {
  JazlaTransferRepositoryImpl({
    required final JazlaStore jazlaStore,
    required final ParcelCompletionStore completionStore,
    required final ImportedJazlaParcelStore importedParcelStore,
    final JazlaTransferCodec codec = const JazlaTransferCodec(),
  })  : _jazlaStore = jazlaStore,
        _completionStore = completionStore,
        _importedParcelStore = importedParcelStore,
        _codec = codec;

  final JazlaStore _jazlaStore;
  final ParcelCompletionStore _completionStore;
  final ImportedJazlaParcelStore _importedParcelStore;
  final JazlaTransferCodec _codec;

  @override
  Future<JazlaTransferBundle> buildExport({
    required final Jazla jazla,
    required final List<Parcel> orderedParcels,
    required final String cityId,
    required final String cityName,
    required final String associationName,
    required final String? associationCode,
    required final AssociationType associationType,
  }) async {
    if (orderedParcels.length > JazlaTransferCodec.maxParcelCount) {
      throw const FormatException('Transfer contains too many parcels.');
    }
    final Map<String, ParcelCompletionStatus> statuses =
        await _completionStore.load(cityId);
    return JazlaTransferBundle(
      manifest: JazlaTransferManifest(
        schemaVersion: JazlaTransferCodec.supportedSchemaVersion,
        bundleType: JazlaTransferCodec.bundleType,
        exportedAt: DateTime.now().toUtc(),
        sourceAppVersion: AppConfig.appVersion,
        cityId: cityId,
        cityName: cityName,
        association: JazlaTransferAssociation(
          name: associationName,
          code: associationCode,
          type: associationType,
        ),
      ),
      jazla: jazla,
      parcels: List<Parcel>.unmodifiable(orderedParcels),
      completionStatuses: <String, ParcelCompletionStatus>{
        for (final String id in jazla.parcelIds)
          if (statuses[id] != null) id: statuses[id]!,
      },
    );
  }

  @override
  Future<Uint8List> encode(final JazlaTransferBundle bundle) async {
    final List<int> bytes = utf8.encode(_codec.encode(bundle));
    if (bytes.length > JazlaTransferCodec.maxBytes) {
      throw const FormatException('Transfer file is too large.');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<JazlaTransferBundle> readFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['hiyaza-jazla', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      throw const FormatException('jazla.transfer.cancelled');
    }
    final PlatformFile file = result.files.single;
    if (file.bytes != null) return _codec.decode(utf8.decode(file.bytes!));
    if (file.path == null) throw const FormatException('Unable to read file.');
    return _codec.decode(await File(file.path!).readAsString());
  }

  @override
  Future<void> importBundle(
    final JazlaTransferBundle bundle, {
    required final bool replace,
  }) async {
    final List<Jazla> existing = await _jazlaStore.load(bundle.jazla.cityId);
    final bool exists =
        existing.any((final Jazla item) => item.id == bundle.jazla.id);
    if (exists && !replace) {
      throw const FormatException('jazla.transfer.conflict');
    }
    final List<Jazla> updated = <Jazla>[
      ...existing.where((final Jazla item) => item.id != bundle.jazla.id),
      bundle.jazla,
    ];
    await _importedParcelStore.save(
      bundle.jazla.cityId,
      bundle.jazla.id,
      bundle.parcels,
    );
    await _jazlaStore.save(bundle.jazla.cityId, updated);
    for (final MapEntry<String, ParcelCompletionStatus> entry
        in bundle.completionStatuses.entries) {
      await _completionStore.saveCompleted(
        bundle.jazla.cityId,
        entry.key,
        entry.value,
      );
    }
  }

  @override
  Future<List<Parcel>> loadFallback(
    final String cityId,
    final String jazlaId,
  ) =>
      _importedParcelStore.load(cityId, jazlaId);
}
