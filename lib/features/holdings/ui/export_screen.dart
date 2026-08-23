import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/local/export_service.dart';
import '../data/model/parcel.dart';
import '../data/repo/holdings_repository.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/ui/dialogs/choice_dialog.dart';

/// Lets a field worker export the active city's data to an .xlsx file
/// before sharing it — either everything or only field-added records,
/// optionally scoped to one حوض (APP_CLAUDE.md § Screen 5).
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final HoldingsRepository _repository = getIt<HoldingsRepository>();
  final ExportService _exportService = const ExportService();

  ExportScope _scope = ExportScope.all;
  String? _basinFilter;
  bool _isExporting = false;

  int get _scopedCount => _repository.parcels
      .where((final Parcel p) => _scope == ExportScope.all || p.isFieldAdded)
      .where((final Parcel p) => _basinFilter == null || p.basinName == _basinFilter)
      .length;

  Future<void> _pickBasin() async {
    final List<String> basins = _repository.availableBasins;
    final ChoiceDialogResult<String>? result = await showChoiceDialog<String>(
      context,
      title: 'holdings.export.pick_basin_title'.tr(),
      options: [
        for (final String b in basins) ChoiceOption<String>(value: b, label: b),
      ],
      selected: _basinFilter,
      clearLabel: 'holdings.export.all_basins'.tr(),
    );
    if (result == null) return;
    setState(() => _basinFilter = result.isClear ? null : result.value);
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final Uint8List? bytes = _exportService.exportToExcel(
        parcels: _repository.parcels,
        scope: _scope,
        basinFilter: _basinFilter,
      );
      if (!mounted) return;
      if (bytes == null) {
        context.showErrorSnackBar('holdings.export.nothing_to_export'.tr());
        return;
      }

      final Directory dir = await getApplicationDocumentsDirectory();
      final String fileName = ExportService.buildExportFileName(
        associationName:
            _repository.defaultAssociationName ?? _repository.activeCityName ?? 'hiyaza',
        basinName: _basinFilter,
        scope: _scope,
      );
      final File file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
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

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: rw(16), vertical: rh(12)),
              child: Row(
                children: [
                  const AppBackButton(),
                  horizontalSpacing(12),
                  Text(
                    'holdings.export.title'.tr(),
                    style: AppTextStyles.font20Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: rw(16)).copyWith(bottom: rh(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel('holdings.export.scope_title'.tr()),
                    verticalSpacing(8),
                    _RadioTile<ExportScope>(
                      label: 'holdings.export.scope_all'.tr(
                        namedArgs: {
                          'count': _repository.parcels.length.toString(),
                        },
                      ),
                      value: ExportScope.all,
                      groupValue: _scope,
                      onChanged: (final ExportScope v) => setState(() => _scope = v),
                    ),
                    _RadioTile<ExportScope>(
                      label: 'holdings.export.scope_added_only'.tr(
                        namedArgs: {
                          'count': _repository.parcels
                              .where((final Parcel p) => p.isFieldAdded)
                              .length
                              .toString(),
                        },
                      ),
                      value: ExportScope.addedOnly,
                      groupValue: _scope,
                      onChanged: (final ExportScope v) => setState(() => _scope = v),
                    ),
                    verticalSpacing(20),
                    _SectionLabel('holdings.export.basin_title'.tr()),
                    verticalSpacing(8),
                    _RadioTile<bool>(
                      label: 'holdings.export.all_basins'.tr(),
                      value: true,
                      groupValue: _basinFilter == null,
                      onChanged: (final bool _) => setState(() => _basinFilter = null),
                    ),
                    InkWell(
                      onTap: _pickBasin,
                      child: _RadioTile<bool>(
                        label: _basinFilter ?? 'holdings.export.pick_basin_title'.tr(),
                        value: false,
                        groupValue: _basinFilter == null,
                        onChanged: (final bool _) => _pickBasin(),
                      ),
                    ),
                    verticalSpacing(20),
                    _SectionLabel('holdings.export.contents_title'.tr()),
                    verticalSpacing(8),
                    _ContentsLine('holdings.export.contents_all_sheet'.tr()),
                    _ContentsLine('holdings.export.contents_basin_sheets'.tr()),
                    verticalSpacing(20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'holdings.export.preview_count'.tr(
                          namedArgs: {'count': _scopedCount.toString()},
                        ),
                        style: AppTextStyles.font14SemiBold.copyWith(
                          color: colors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    verticalSpacing(20),
                    CustomTextButton(
                      text: 'holdings.export.export_button'.tr(),
                      onPressed: _scopedCount == 0 ? null : _export,
                      isLoading: _isExporting,
                      size: CustomButtonSize.large,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(final BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.font14Bold.copyWith(
        color: context.customColors.textPrimary,
      ),
      textAlign: TextAlign.right,
    );
  }
}

class _RadioTile<T> extends StatelessWidget {
  const _RadioTile({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Object? groupValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final bool isSelected = groupValue == value;

    return InkWell(
      onTap: () => onChanged(value),
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

class _ContentsLine extends StatelessWidget {
  const _ContentsLine(this.label);

  final String label;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: colors.success),
          horizontalSpacing(8),
          Text(
            label,
            style: AppTextStyles.font12Regular.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
