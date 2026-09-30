import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../cities/data/model/association_type.dart';

/// Home's city identity and its four high-frequency actions. Operational
/// counts intentionally live in the visibility sheet so long association
/// names retain room in the header.
class HomeMainCard extends StatelessWidget {
  const HomeMainCard({
    super.key,
    required this.onChangeCity,
    required this.onOpenJazla,
    required this.onOpenSearchFilter,
    this.cityName,
    this.associationType,
  });

  final VoidCallback onChangeCity;
  final VoidCallback onOpenJazla;
  final VoidCallback onOpenSearchFilter;
  final String? cityName;
  final AssociationType? associationType;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Container(
      padding: EdgeInsets.fromLTRB(rw(16), rh(16), rw(16), rh(14)),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (cityName != null) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AssociationMark(type: associationType),
                horizontalSpacing(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        cityName!,
                        style: AppTextStyles.font20Bold.copyWith(
                          color: colors.textPrimary,
                          height: 1.25,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      if (associationType != null) ...<Widget>[
                        verticalSpacing(4),
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
              ],
            ),
            verticalSpacing(16),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: _PrimaryAction(
                  icon: Icons.layers_rounded,
                  label: 'jazla.title'.tr(),
                  onTap: onOpenJazla,
                ),
              ),
              horizontalSpacing(8),
              _HeaderIconAction(
                icon: Icons.handyman_rounded,
                tooltip: 'cities.tools.entry'.tr(),
                onTap: () => context.pushNamed(Routes.cityTools),
              ),
              horizontalSpacing(8),
              _HeaderIconAction(
                icon: Icons.tune_rounded,
                tooltip: 'holdings.home.activity.filter_title'.tr(),
                onTap: onOpenSearchFilter,
                emphasized: true,
              ),
              horizontalSpacing(8),
              _HeaderIconAction(
                icon: Icons.swap_horiz_rounded,
                tooltip: 'holdings.home.change_file'.tr(),
                onTap: onChangeCity,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms, curve: Curves.easeOut).slideY(
          begin: .03,
          end: 0,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _AssociationMark extends StatelessWidget {
  const _AssociationMark({required this.type});

  final AssociationType? type;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final IconData icon = type == AssociationType.agriculturalReform
        ? Icons.account_balance_rounded
        : Icons.agriculture_rounded;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary200.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: colors.iconPrimary, size: 23),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: AppColors.primary200,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 19, color: AppColors.white),
                  horizontalSpacing(8),
                  Flexible(
                    child: Text(
                      label,
                      style: AppTextStyles.font14SemiBold
                          .copyWith(color: AppColors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _HeaderIconAction extends StatelessWidget {
  const _HeaderIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final Color foreground =
        emphasized ? AppColors.primary200 : colors.iconSecondary;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: emphasized
              ? AppColors.primary200.withValues(alpha: .14)
              : colors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: foreground, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
