import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../jazla/data/model/jazla.dart';
import '../../data/model/jazla_transfer_bundle.dart';

Future<bool?> showJazlaTransferPreviewSheet(
  final BuildContext context, {
  required final JazlaTransferBundle bundle,
  required final bool hasConflict,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.customColors.surface,
      builder: (final BuildContext sheetContext) => _TransferPreview(
        sheetContext: sheetContext,
        bundle: bundle,
        hasConflict: hasConflict,
      ),
    );

class _TransferPreview extends StatelessWidget {
  const _TransferPreview({
    required this.sheetContext,
    required this.bundle,
    required this.hasConflict,
  });

  final BuildContext sheetContext;
  final JazlaTransferBundle bundle;
  final bool hasConflict;

  @override
  Widget build(final BuildContext context) {
    final Jazla jazla = bundle.jazla;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.customColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const Icon(Icons.layers_rounded, color: AppColors.primary200),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'jazla.transfer.preview_title'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _InfoRow(label: 'jazla.transfer.jazla'.tr(), value: jazla.name),
          _InfoRow(
            label: 'jazla.transfer.basin'.tr(),
            value: jazla.basinName ?? '—',
          ),
          _InfoRow(
            label: 'jazla.transfer.city'.tr(),
            value: bundle.manifest.cityName,
          ),
          _InfoRow(
            label: 'jazla.transfer.association'.tr(),
            value: bundle.manifest.association.name,
          ),
          _InfoRow(
            label: 'jazla.transfer.parcels'.tr(),
            value: '${bundle.parcels.length}',
          ),
          _InfoRow(
            label: 'jazla.transfer.target_area'.tr(),
            value: jazla.targetAreaSqm == null
                ? 'jazla.area.no_target'.tr()
                : '${jazla.targetAreaSqm!.toStringAsFixed(2)} m²',
          ),
          _InfoRow(
            label: 'jazla.transfer.exported_at'.tr(),
            value: bundle.manifest.exportedAt.toLocal().toString(),
          ),
          _InfoRow(
            label: 'jazla.transfer.source_app'.tr(),
            value: bundle.manifest.sourceAppVersion,
          ),
          if (hasConflict) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'jazla.transfer.conflict_message'.tr(),
              style: TextStyle(color: context.customColors.warning),
              textAlign: TextAlign.right,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(sheetContext, true),
            icon: Icon(hasConflict
                ? Icons.sync_alt_rounded
                : Icons.file_download_done_rounded),
            label: Text(
              hasConflict
                  ? 'jazla.transfer.replace'.tr()
                  : 'jazla.transfer.import_confirm'.tr(),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext, false),
            child: Text('app_dialogs.cancel'.tr()),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: context.customColors.textSecondary),
            ),
          ],
        ),
      );
}
