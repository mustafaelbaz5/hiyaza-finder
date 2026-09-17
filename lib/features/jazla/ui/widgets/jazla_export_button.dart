import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../holdings/data/local/export_file_saver.dart';
import '../../../holdings/data/model/parcel.dart';
import '../../../holdings/data/repo/holdings_repository.dart';
import '../../data/local/jazla_export_service.dart';

class JazlaExportButton extends StatefulWidget {
  const JazlaExportButton({
    super.key,
    required this.jazlaName,
    required this.parcels,
  });

  final String jazlaName;
  final List<Parcel> parcels;

  @override
  State<JazlaExportButton> createState() => _JazlaExportButtonState();
}

class _JazlaExportButtonState extends State<JazlaExportButton> {
  bool _isExporting = false;

  Future<void> _export() async {
    if (widget.parcels.isEmpty) {
      context.showErrorSnackBar('jazla.export.empty'.tr());
      return;
    }
    setState(() => _isExporting = true);
    try {
      final Uint8List? bytes = getIt<JazlaExportService>().export(
        jazlaName: widget.jazlaName,
        orderedParcels: widget.parcels,
      );
      if (bytes == null) {
        if (mounted) context.showErrorSnackBar('jazla.export.empty'.tr());
        return;
      }
      final String cityName = getIt<HoldingsRepository>().activeCityName ?? '';
      final String fileName = JazlaExportService.buildFileName(cityName, widget.jazlaName);
      await saveExportFile(bytes: bytes, fileName: fileName);
      if (mounted) context.showSuccessSnackBar('jazla.export.success'.tr());
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    return IconButton(
      icon: _isExporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined),
      onPressed: _isExporting ? null : _export,
    );
  }
}
