import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import 'top_bar_icon_button.dart';

/// Home's header — 🏘 Basins page, ⚙️ City Tools, 🔄 change city
/// (APP_CLAUDE.md § 9.1). No Wi-Fi/connectivity indicator and no basin
/// filter icon — internet is only relevant during a city download, which
/// already surfaces its own error on failure; a persistent status badge
/// added nothing the rest of the time.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.onChangeCity});

  final VoidCallback onChangeCity;

  @override
  Widget build(final BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rw(12), vertical: rh(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
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
