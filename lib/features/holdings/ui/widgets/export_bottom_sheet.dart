import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../data/local/export_service.dart';
import '../../data/model/parcel.dart';
import '../../data/repo/holdings_repository.dart';

/// Simple export sheet reached from [BasinScreen]'s export button
/// (APP_CLAUDE.md § 9.3) — always scoped to the one basin it's opened
/// from, unlike the full `ExportScreen` (all cities/basins).
Future<void> showExportBottomSheet(
  final BuildContext context, {
  required final String basinName,
  required final List<Parcel> basinParcels,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => _ExportBottomSheet(
      basinName: basinName,
      basinParcels: basinParcels,
    ),
  );
}

class _ExportBottomSheet extends StatefulWidget {
  const _ExportBottomSheet({required this.basinName, required this.basinParcels});

  final String basinName;
  final List<Parcel> basinParcels;

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  static const ExportService _exportService = ExportService();

  ExportScope _scope = ExportScope.all;
  bool _isExporting = false;

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final Uint8List? bytes = _exportService.exportToExcel(
        parcels: widget.basinParcels,
        scope: _scope,
        basinFilter: widget.basinName,
      );
      if (!mounted) return;
      if (bytes == null) {
        context.showErrorSnackBar('holdings.export.nothing_to_export'.tr());
        return;
      }

      final HoldingsRepository repository = getIt<HoldingsRepository>();
      final Directory dir = await getApplicationDocumentsDirectory();
      final String fileName = ExportService.buildExportFileName(
        associationName:
            repository.defaultAssociationName ?? repository.activeCityName ?? 'hiyaza',
        basinName: widget.basinName,
        scope: _scope,
      );
      final File file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      Navigator.pop(context);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], fileNameOverrides: [fileName]),
      );
    } catch (_) {
      if (mounted) context.showErrorSnackBar('errors.unknown'.tr());
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(rw(20), rh(16), rw(20), rh(24)),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            verticalSpacing(16),
            Text(
              'holdings.export.basin_export_title'.tr(
                namedArgs: {'basin': widget.basinName},
              ),
              style: AppTextStyles.font18Bold.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(16),
            _ScopeTile(
              label: 'holdings.export.scope_all'.tr(
                namedArgs: {'count': widget.basinParcels.length.toString()},
              ),
              isSelected: _scope == ExportScope.all,
              onTap: () => setState(() => _scope = ExportScope.all),
            ),
            verticalSpacing(8),
            _ScopeTile(
              label: 'holdings.export.scope_added_only'.tr(
                namedArgs: {
                  'count': widget.basinParcels
                      .where((final Parcel p) => p.isFieldAdded)
                      .length
                      .toString(),
                },
              ),
              isSelected: _scope == ExportScope.addedOnly,
              onTap: () => setState(() => _scope = ExportScope.addedOnly),
            ),
            verticalSpacing(20),
            CustomTextButton(
              text: 'holdings.export.export_button'.tr(),
              onPressed: _export,
              isLoading: _isExporting,
              size: CustomButtonSize.large,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary200 : colors.iconSecondary,
            ),
            horizontalSpacing(10),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.font14Regular.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
