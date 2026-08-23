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

/// Home's header — city name + association-type subtitle on the right,
/// 🏘 Basins page / ⚙️ City Tools / 🔄 change-city icons on the left
/// (UI/UX Updates prompt "Change 3"). No Wi-Fi/connectivity indicator and
/// no basin filter icon — internet is only relevant during a city
/// download, which already surfaces its own error on failure; a persistent
/// status badge added nothing the rest of the time.
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
      padding: EdgeInsets.symmetric(horizontal: rw(16), vertical: rh(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (cityName != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    cityName,
                    style: AppTextStyles.font18Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (type != null)
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
              ),
            )
          else
            const Spacer(),
          TopBarIconButton(
            icon: Icons.holiday_village_rounded,
            tooltip: 'holdings.basin.title'.tr(),
            onTap: () => context.pushNamed(Routes.basins),
          ),
          horizontalSpacing(8),
          TopBarIconButton(
            icon: Icons.build_outlined,
            tooltip: 'cities.tools.entry'.tr(),
            onTap: () => context.pushNamed(Routes.cityTools),
          ),
          horizontalSpacing(8),
          TopBarIconButton(
            icon: Icons.swap_horiz_rounded,
            tooltip: 'holdings.home.change_file'.tr(),
            onTap: onChangeCity,
          ),
        ],
      ),
    );
  }
}
