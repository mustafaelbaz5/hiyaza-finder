import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../cities/data/model/association_type.dart';

/// Home's compact city summary and quick actions.
class HomeMainCard extends StatelessWidget {
  const HomeMainCard({
    super.key,
    required this.onChangeCity,
    required this.onOpenJazla,
    required this.onOpenSearchFilter,
    this.cityName,
    this.associationType,
    this.parcelCount = 0,
    this.activeParcelCount,
    this.zeroAreaParcelCount,
  });

  final VoidCallback onChangeCity;
  final VoidCallback onOpenJazla;
  final VoidCallback onOpenSearchFilter;
  final String? cityName;
  final AssociationType? associationType;
  final int parcelCount;
  final int? activeParcelCount;
  final int? zeroAreaParcelCount;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final int activeCount = activeParcelCount ?? parcelCount;
    final int zeroCount = zeroAreaParcelCount ?? 0;

    return Container(
      padding: EdgeInsets.fromLTRB(rw(16), rh(14), rw(16), rh(14)),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (cityName != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        cityName!,
                        style: AppTextStyles.font18Bold.copyWith(
                          color: colors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (associationType != null) ...<Widget>[
                        verticalSpacing(2),
                        Text(
                          associationType == AssociationType.agriculturalReform
                              ? 'holdings.association_type.agricultural_reform'
                                  .tr()
                              : 'holdings.association_type.agricultural_credit'
                                  .tr(),
                          style: AppTextStyles.font12Regular.copyWith(
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ],
                  ),
                ),
                horizontalSpacing(10),
                _IconActionButton(
                  icon: Icons.filter_alt_rounded,
                  tooltip: 'holdings.home.activity.filter_title'.tr(),
                  onTap: onOpenSearchFilter,
                ),
                horizontalSpacing(8),
                _IconActionButton(
                  icon: Icons.change_circle_outlined,
                  tooltip: 'holdings.home.change_file'.tr(),
                  onTap: onChangeCity,
                ),
              ],
            ),
          if (cityName != null) verticalSpacing(14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: <Widget>[
              _Metric(
                  value: activeCount,
                  label: 'holdings.home.activity.active_parcels'.tr(),
                  color: AppColors.primary200),
              _Metric(
                  value: parcelCount,
                  label: 'holdings.home.activity.total_records'.tr(),
                  color: colors.textSecondary),
              _Metric(
                  value: zeroCount,
                  label: 'holdings.home.activity.zero_area_short'.tr(),
                  color: colors.textHint),
            ]),
          ),
          verticalSpacing(14),
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionButton(
                  icon: Icons.layers_outlined,
                  label: 'jazla.title'.tr(),
                  onTap: onOpenJazla,
                ),
              ),
              horizontalSpacing(8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.build_outlined,
                  label: 'cities.tools.entry'.tr(),
                  onTap: () => context.pushNamed(Routes.cityTools),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms, curve: Curves.easeOut).slideY(
        begin: 0.03, end: 0, duration: 220.ms, curve: Curves.easeOutCubic);
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.value, required this.label, required this.color});
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(final BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('$value',
                style: AppTextStyles.font18Bold.copyWith(color: color)),
            Text(label,
                style: AppTextStyles.font12Regular.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.primary200),
              horizontalSpacing(8),
              Flexible(
                  child: Text(label,
                      style: AppTextStyles.font14SemiBold
                          .copyWith(color: colors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary200.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary200, size: 24),
            ),
          ),
        ),
      );
}
