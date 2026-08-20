import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import 'inline_action.dart';


class FileInfoCard extends StatelessWidget {
  const FileInfoCard({
    super.key,
    required this.holdingCount,
    required this.selectedBasin,
    required this.hasBasins,
    required this.onChangeFile,
    required this.onOpenBasinFilter,
    required this.onOpenFileStatus,
  });

  final int holdingCount;
  final String? selectedBasin;
  final bool hasBasins;
  final VoidCallback onChangeFile;
  final VoidCallback onOpenBasinFilter;
  final VoidCallback onOpenFileStatus;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
      padding: EdgeInsets.all(rw(16)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary50.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.dataset_rounded,
                  color: AppColors.primary200,
                ),
              ),
              horizontalSpacing(12),
              Expanded(
                child: Text(
                  'holdings.home.holdings_loaded'.tr(
                    namedArgs: {'count': holdingCount.toString()},
                  ),
                  style: AppTextStyles.font18Bold.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          if (hasBasins) ...<Widget>[
            verticalSpacing(12),
            Row(
              children: <Widget>[
                Expanded(
                  child: InlineAction(
                    icon: Icons.filter_alt_rounded,
                    label: selectedBasin == null
                        ? 'holdings.basin.all'.tr()
                        : 'holdings.basin.focus_label'.tr(
                            namedArgs: {'basin': selectedBasin!},
                          ),
                    onTap: onOpenBasinFilter,
                    highlighted: selectedBasin != null,
                  ),
                ),
                horizontalSpacing(10),
                Expanded(
                  child: InlineAction(
                    icon: Icons.swap_horiz_rounded,
                    label: 'holdings.home.change_file'.tr(),
                    onTap: onChangeFile,
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            verticalSpacing(12),
            InlineAction(
              icon: Icons.swap_horiz_rounded,
              label: 'holdings.home.change_file'.tr(),
              onTap: onChangeFile,
            ),
          ],
          verticalSpacing(10),
          InlineAction(
            icon: Icons.dashboard_customize_rounded,
            label: 'holdings.bulk_edit.entry_pill'.tr(),
            onTap: onOpenFileStatus,
          ),
        ],
      ),
    );
  }
}
