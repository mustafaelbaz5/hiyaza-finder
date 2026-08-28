import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../cities/data/model/association_type.dart';
import '../../data/repo/holdings_repository.dart';

/// Home's single, prominent card (UI/UX redesign, restyled to match a
/// reference dark-chip design) — city name plus the 3 tool actions
/// (Basins/City Tools/Change City) as labeled pill buttons, matching the
/// reference's "تغيير المد..." / "الكل" pill look instead of bare
/// icon-only chips. The search bar itself lives just below this card as
/// its own element (`HomeScreen`), not inside it — matching the reference
/// layout exactly.
class HomeMainCard extends StatelessWidget {
  const HomeMainCard({super.key, required this.onChangeCity});

  final VoidCallback onChangeCity;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final HoldingsRepository repository = getIt<HoldingsRepository>();
    final String? cityName = repository.activeCityName;
    final AssociationType? type = repository.activeAssociationType;
    final int parcelCount = repository.parcels.length;

    return Container(
      padding: EdgeInsets.fromLTRB(rw(18), rh(18), rw(18), rh(18)),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cityName != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cityName,
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
                      if (parcelCount > 0) ...[
                        verticalSpacing(2),
                        Text(
                          'holdings.home.holdings_loaded'
                              .tr(namedArgs: {'count': parcelCount.toString()}),
                          style: AppTextStyles.font12Regular.copyWith(
                            color: AppColors.primary200,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ],
                  ),
                ),
                horizontalSpacing(10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary200.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: AppColors.primary200,
                    size: 22,
                  ),
                ),
              ],
            ),
            verticalSpacing(16),
          ],
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'holdings.home.change_file'.tr(),
                  onTap: onChangeCity,
                ),
              ),
              horizontalSpacing(10),
              Expanded(
                child: _PillButton(
                  icon: Icons.layers_outlined,
                  label: 'jazla.title'.tr(),
                  onTap: () => context.pushNamed(Routes.jazlaList),
                ),
              ),
            ],
          ),
          verticalSpacing(10),
          _PillButton(
            icon: Icons.build_outlined,
            label: 'cities.tools.entry'.tr(),
            onTap: () => context.pushNamed(Routes.cityTools),
          ),
        ],
      ),
    );
  }
}

/// A full-width-capable, rounded pill button — icon + label side by side,
/// matching the reference design's "تغيير المد..." / "الكل" buttons.
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
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
    );
  }
}
