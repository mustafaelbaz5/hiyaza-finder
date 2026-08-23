import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../cities/data/model/association_type.dart';
import '../../data/repo/holdings_repository.dart';
import 'top_bar_icon_button.dart';

/// Home's header (UI/UX Updates prompt "Change 5") — city name +
/// association-type subtitle on the right, 🏘 Basins page / ⚙️ City Tools /
/// 🔄 change-city icons clearly spaced on the left. Taller and more
/// generously padded than the old single-row bar so the title block and
/// icon row each get their own breathing room instead of being squeezed
/// into one thin strip. The search bar used to effectively live here too
/// (right at the top of the body); it's now its own elevated card in
/// `HomeScreen`, entirely separate from this bar. No Wi-Fi/connectivity
/// indicator and no basin filter icon — internet is only relevant during a
/// city download, which already surfaces its own error on failure; a
/// persistent status badge added nothing the rest of the time.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.onChangeCity});

  final VoidCallback onChangeCity;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final HoldingsRepository repository = getIt<HoldingsRepository>();
    final String? cityName = repository.activeCityName;
    final AssociationType? type = repository.activeAssociationType;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rw(16), vertical: rh(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (cityName != null) ...[
            Text(
              cityName,
              style: AppTextStyles.font20Bold.copyWith(
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
                    ? 'holdings.association_type.agricultural_reform'.tr()
                    : 'holdings.association_type.agricultural_credit'.tr(),
                style: AppTextStyles.font12Regular.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.right,
              ),
            ],
            verticalSpacing(14),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TopBarIconButton(
                icon: Icons.holiday_village_rounded,
                tooltip: 'holdings.basin.title'.tr(),
                onTap: () => context.pushNamed(Routes.basins),
              ),
              horizontalSpacing(12),
              TopBarIconButton(
                icon: Icons.build_outlined,
                tooltip: 'cities.tools.entry'.tr(),
                onTap: () => context.pushNamed(Routes.cityTools),
              ),
              horizontalSpacing(12),
              TopBarIconButton(
                icon: Icons.swap_horiz_rounded,
                tooltip: 'holdings.home.change_file'.tr(),
                onTap: onChangeCity,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
