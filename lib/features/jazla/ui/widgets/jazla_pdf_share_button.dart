import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/extensions/context_ext.dart';
import '../../data/local/jazla_pdf_export_service.dart';
import '../../data/model/jazla.dart';
import '../../../holdings/data/model/parcel.dart';

class JazlaPdfShareButton extends StatefulWidget {
  const JazlaPdfShareButton({
    super.key,
    required this.jazla,
    required this.parcels,
  });

  final Jazla jazla;
  final List<Parcel> parcels;

  @override
  State<JazlaPdfShareButton> createState() => _JazlaPdfShareButtonState();
}

class _JazlaPdfShareButtonState extends State<JazlaPdfShareButton> {
  bool _busy = false;

  Future<void> _share() async {
    if (widget.parcels.isEmpty) {
      context.showErrorSnackBar('jazla.export.empty'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      final Uint8List bytes = await const JazlaPdfExportService().export(
        jazla: widget.jazla,
        parcels: widget.parcels,
      );
      final String safeName =
          widget.jazla.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes,
                name: '${safeName}_jazla.pdf', mimeType: 'application/pdf')
          ],
          subject: widget.jazla.name,
        ),
      );
    } catch (error) {
      if (mounted) context.showErrorSnackBar('jazla.export.pdf_failed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(final BuildContext context) => IconButton(
        tooltip: 'jazla.export.pdf'.tr(),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.picture_as_pdf_outlined),
        onPressed: _busy ? null : _share,
      );
}
