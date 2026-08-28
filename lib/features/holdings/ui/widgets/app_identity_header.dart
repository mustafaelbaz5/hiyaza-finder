import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/settings/ui/settings_sheet.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import 'top_bar_icon_button.dart';

/// Home's AppBar-style top row — centered brand name ("حيازة") + logo /
/// version, with a single settings icon chip. No refresh action — the app
/// already keeps its local data current without a manual reload button, so
/// this row is now just identity + one settings entry point, matching a
/// reference design's centered-title AppBar layout minus the actions this
/// app doesn't have (no wifi/connectivity indicator, no refresh).
class AppIdentityHeader extends StatelessWidget {
  const AppIdentityHeader({super.key});

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Padding(
      padding: EdgeInsets.fromLTRB(rw(16), rh(8), rw(16), rh(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Balances the settings chip on the other side so the centered
          // title block stays visually centered in the row.
          SizedBox(width: rw(44)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'holdings.home.brand'.tr(),
                      style: AppTextStyles.font18Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    horizontalSpacing(8),
                    SizedBox(
                      width: rw(22),
                      height: rh(22),
                      child: const Icon(
                        Icons.landscape_rounded,
                        color: AppColors.primary200,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                Text(
                  'v${AppConfig.appVersion}',
                  style: AppTextStyles.font12Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TopBarIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'holdings.home.settings'.tr(),
            onTap: () => showSettingsSheet(context),
          ),
        ],
      ),
    );
  }
}

/// Low-emphasis "تطوير: {developerName}" footer badge — tappable,
/// deep-links to the existing About screen so this stays a discovery hint
/// rather than duplicating About's full content. Reuses the
/// `about.footer.made_with_love` translation key already built for this
/// exact string in `AboutScreen`, so the wording can't drift between the
/// two places it appears.
///
/// Only shown on Home's empty/init state (no active search) — it hides
/// itself once the user starts searching, so it never competes with
/// results for space. `HomeScreen` pins this via
/// `Scaffold.resizeToAvoidBottomInset: false` so opening the keyboard for
/// the search field doesn't shove it up the screen the way a plain
/// `Column` child would.
class DeveloperFooterBadge extends StatelessWidget {
  const DeveloperFooterBadge({super.key, required this.isSearching});

  final bool isSearching;

  @override
  Widget build(final BuildContext context) {
    if (isSearching) return const SizedBox.shrink();

    final colors = context.customColors;

    return InkWell(
      onTap: () => context.pushNamed(Routes.aboutScreen),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(16), vertical: rh(3)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 11, color: colors.textHint),
            horizontalSpacing(4),
            Text(
              '${'about.footer.made_with_love'.tr()} ${AppConfig.developerName}',
              style: AppTextStyles.font12Regular.copyWith(
                color: colors.textHint,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
