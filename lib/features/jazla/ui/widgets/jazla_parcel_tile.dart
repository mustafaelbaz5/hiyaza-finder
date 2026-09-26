import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/themes/custom_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../holdings/data/local/clipboard_formatter.dart';
import '../../../holdings/data/model/parcel.dart';

/// One row inside [JazlaDetailScreen]'s "القطع الموجودة" tab — sequence
/// number, حائز, حوض, المساحة (full unit names), نوع المحصول. Tapping opens
/// the app's existing full Detail Screen (handled by the caller), long
/// press offers removal from this Jazla only (never the underlying parcel).
class JazlaParcelTile extends StatelessWidget {
  const JazlaParcelTile({
    super.key,
    required this.index,
    required this.parcel,
    required this.onTap,
    this.onLongPress,
  });

  final int index;
  final Parcel parcel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static const ClipboardFormatter _formatter = ClipboardFormatter();

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String holder = parcel.holderName?.trim().isNotEmpty == true
        ? parcel.holderName!.trim()
        : '—';
    final String basin = parcel.basinName?.trim().isNotEmpty == true
        ? parcel.basinName!.trim()
        : '—';
    final String cropType = parcel.cropType?.trim() ?? '';
    // Same formatter the main Detail Screen uses — plain `.toString()`
    // rendering, always Western digits, never derived from ambient locale.
    final String feddan = _formatter.formatNumber(parcel.feddan) ?? '0';
    final String qirat = _formatter.formatNumber(parcel.qirat) ?? '0';
    final String sahm = _formatter.formatNumber(parcel.sahm) ?? '0';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary50.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: AppTextStyles.font12Bold
                      .copyWith(color: AppColors.primary200),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      holder,
                      style: AppTextStyles.font16SemiBold
                          .copyWith(color: colors.textPrimary),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _InfoLine(
                      label: 'holdings.fields.basin_name'.tr(),
                      value: basin,
                      colors: colors,
                    ),
                    const SizedBox(height: 4),
                    _InfoLine(
                      label: 'jazla.detail.area_label'.tr(),
                      value: 'jazla.detail.area_value'.tr(
                        namedArgs: {
                          'feddan': feddan,
                          'qirat': qirat,
                          'sahm': sahm,
                        },
                      ),
                      colors: colors,
                    ),
                    if (parcel.cropType?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      _InfoLine(
                        label: 'holdings.fields.crop_type'.tr(),
                        value: cropType,
                        colors: colors,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.drag_handle_rounded, color: colors.iconSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(
      {required this.label, required this.value, required this.colors});

  final String label;
  final String value;
  final CustomColors colors;

  @override
  Widget build(final BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: AppTextStyles.font12Regular
                .copyWith(color: colors.textSecondary),
          ),
          TextSpan(
            text: value,
            style:
                AppTextStyles.font12Regular.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
      textAlign: TextAlign.right,
    );
  }
}
