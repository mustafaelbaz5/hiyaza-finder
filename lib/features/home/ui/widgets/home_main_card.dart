import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../cities/data/model/association_type.dart';

/// Home's compact city summary and quick-actions card.
class HomeMainCard extends StatelessWidget {
  const HomeMainCard({
    super.key,
    required this.onChangeCity,
    required this.onOpenJazla,
    this.cityName,
    this.associationType,
    this.parcelCount = 0,
  });

  final VoidCallback onChangeCity;
  final VoidCallback onOpenJazla;
  final String? cityName;
  final AssociationType? associationType;
  final int parcelCount;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final AssociationType? type = associationType;
    final String? activeCityName = cityName;

    return Container(
      padding: EdgeInsets.fromLTRB(rw(16), rh(14), rw(16), rh(14)),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeCityName != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeCityName,
                        style: AppTextStyles.font18Bold.copyWith(
                          color: colors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (type != null) ...[
                        verticalSpacing(2),
                        Text(
                          type == AssociationType.agriculturalReform
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
                      verticalSpacing(4),
                      Text(
                        'holdings.home.holdings_loaded'
                            .tr(namedArgs: {'count': parcelCount.toString()}),
                        style: AppTextStyles.font12Bold.copyWith(
                          color: AppColors.primary200,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                horizontalSpacing(10),
                _IconActionButton(
                  icon: Icons.change_circle_outlined,
                  tooltip: 'holdings.home.change_file'.tr(),
                  onTap: onChangeCity,
                ),
              ],
            ),
            verticalSpacing(16),
          ],
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  icon: Icons.layers_outlined,
                  label: 'jazla.title'.tr(),
                  onTap: onOpenJazla,
                ),
              ),
              horizontalSpacing(8),
              Expanded(
                child: _PillButton(
                  icon: Icons.build_outlined,
                  label: 'cities.tools.entry'.tr(),
                  onTap: () => context.pushNamed(Routes.cityTools),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: 220.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.03,
          end: 0,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// A compact labeled action for the two primary Home actions.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.font14SemiBold.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              horizontalSpacing(8),
              Icon(icon, size: 18, color: AppColors.primary200),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    return Semantics(
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
              border: Border.all(
                  color: AppColors.primary200.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: AppColors.primary200, size: 24),
          ),
        ),
      ),
    );
  }
}
