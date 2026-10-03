import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../parcel_catalog/data/model/parcel.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../parcel_details/data/local/clipboard_formatter.dart';
import '../../data/local/jazla_search_service.dart';
import 'jazla_locked_badge.dart';

/// A compact, parcel-level search result. The person action is intentionally
/// available even when this specific parcel is already claimed by another
/// Jazla: it creates a distinct new parcel and never changes the locked one.
class JazlaParcelResultTile extends StatelessWidget {
  const JazlaParcelResultTile({
    super.key,
    required this.result,
    required this.onAddTap,
    required this.onEditTap,
    required this.onAddForPerson,
  });

  final ParcelSearchResult result;
  final VoidCallback onAddTap;
  final VoidCallback onEditTap;
  final VoidCallback onAddForPerson;

  static const ClipboardFormatter _formatter = ClipboardFormatter();

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final Parcel parcel = result.parcel;
    final String holder = parcel.holderName?.trim().isNotEmpty == true
        ? parcel.holderName!.trim()
        : '—';
    final String basin = parcel.basinName?.trim().isNotEmpty == true
        ? parcel.basinName!.trim()
        : '—';
    final String holdingId =
        parcel.holdingId.trim().isNotEmpty ? parcel.holdingId.trim() : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary50.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary200,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: holder,
                        style: AppTextStyles.font14SemiBold
                            .copyWith(color: colors.textPrimary),
                      ),
                      TextSpan(
                        text: '  •  $basin',
                        style: AppTextStyles.font12Regular
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (result.isLocked)
                JazlaLockedBadge(jazlaName: result.jazlaName!),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ResultMetric(
                  icon: Icons.tag_rounded,
                  label: 'holdings.fields.holding_id'.tr(),
                  value: holdingId,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _ResultMetric(
                  icon: Icons.straighten_rounded,
                  label: 'holdings.fields.area'.tr(),
                  value: _areaText(parcel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Tooltip(
                message: 'jazla.add_sheet.add_parcel_for_person'.tr(),
                child: Semantics(
                  button: true,
                  label: 'jazla.add_sheet.add_parcel_for_person'.tr(),
                  child: IconButton(
                    onPressed: onAddForPerson,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    color: AppColors.primary200,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              if (!result.isLocked) ...[
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEditTap,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text('jazla.add_sheet.view_edit'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 104,
                  child: FilledButton.icon(
                    onPressed: onAddTap,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('jazla.add_sheet.add'.tr()),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: Text(
                    'jazla.add_sheet.add_parcel_for_person'.tr(),
                    style: AppTextStyles.font12Regular
                        .copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _areaText(final Parcel parcel) {
    final String? feddan = _formatter.formatNumber(parcel.feddan);
    final String? qirat = _formatter.formatNumber(parcel.qirat);
    final String? sahm = _formatter.formatNumber(parcel.sahm);
    if (feddan == null && qirat == null && sahm == null) {
      return 'jazla.add_sheet.area_missing'.tr();
    }
    return '${feddan ?? '0'} فدان، ${qirat ?? '0'} قيراط، ${sahm ?? '0'} سهم';
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary200),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.font12Regular
                      .copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.font12Bold
                      .copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
