import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../data/local/clipboard_formatter.dart';
import '../../data/model/parcel.dart';

class AreaSummaryCard extends StatelessWidget {
  const AreaSummaryCard({
    required this.parcel,
    required this.onTap,
    this.isModified = false,
    super.key,
  });

  final Parcel parcel;
  final VoidCallback onTap;
  final bool isModified;

  static const ClipboardFormatter _formatter = ClipboardFormatter();

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(rw(10)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isModified ? AppColors.primary200 : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                textDirection: Directionality.of(context),
                children: <Widget>[
                  const Icon(
                    Icons.straighten_rounded,
                    size: 17,
                    color: AppColors.primary200,
                  ),
                  horizontalSpacing(6),
                  Text(
                    'المساحة',
                    style: AppTextStyles.font12Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _copyArea(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.copy_rounded,
                        size: 16, color: colors.textHint),
                    tooltip: 'holdings.field.copy_tooltip'.tr(),
                  ),
                ],
              ),
              verticalSpacing(8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _AreaUnit(
                      value: _formatter.formatNumber(parcel.feddan),
                      label: 'فدان',
                      color: AppColors.green200,
                    ),
                  ),
                  horizontalSpacing(6),
                  Expanded(
                    child: _AreaUnit(
                      value: _formatter.formatNumber(parcel.qirat),
                      label: 'قيراط',
                      color: AppColors.blue200,
                    ),
                  ),
                  horizontalSpacing(6),
                  Expanded(
                    child: _AreaUnit(
                      value: _formatter.formatNumber(parcel.sahm),
                      label: 'سهم',
                      color: AppColors.amber200,
                    ),
                  ),
                ],
              ),
              verticalSpacing(8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary200.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  textDirection: Directionality.of(context),
                  children: <Widget>[
                    const Icon(Icons.square_foot_rounded,
                        size: 16, color: AppColors.primary200),
                    horizontalSpacing(6),
                    Text(
                      'المساحة بالمتر المربع',
                      style: AppTextStyles.font12Regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_formatter.formatNumber(parcel.totalSqm) ?? '-'} م²',
                      style: AppTextStyles.font14Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyArea(final BuildContext context) async {
    final String text =
        '${_formatter.areaFraction(parcel)} | ${_formatter.formatNumber(parcel.totalSqm) ?? '-'} م²';
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      HapticFeedback.lightImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
  }
}

class _AreaUnit extends StatelessWidget {
  const _AreaUnit(
      {required this.value, required this.label, required this.color});

  final String? value;
  final String label;
  final Color color;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value ?? '-',
            style: AppTextStyles.font16Bold.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.font12Regular
                .copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
