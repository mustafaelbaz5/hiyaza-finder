import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/config/app_config.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/top_bar_icon_button.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.onSettings,
  });

  final VoidCallback onSettings;

  /// Matches [TopBarIconButton]'s footprint so the centered title/brand
  /// column stays visually centered without a second icon button on the
  /// trailing side. There is no manual-refresh action here anymore
  /// (`REFACTOR_ROADMAP.md` Phase 9 #8 — Realtime plus a silent
  /// resume-triggered resync replaced it); this spacer keeps the layout
  /// unchanged rather than re-centering the title column.
  static const double _iconButtonFootprint = 42;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rw(12), vertical: rh(8)),
      child: Row(
        children: <Widget>[
          TopBarIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'settings.title'.tr(),
            onTap: onSettings,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.landscape_rounded,
                      color: AppColors.primary200,
                      size: 22,
                    ),
                    horizontalSpacing(6),
                    Text(
                      'holdings.home.brand'.tr(),
                      style: AppTextStyles.font20Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'v${AppConfig.appVersion}',
                  style: AppTextStyles.font12Regular.copyWith(
                    color: colors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: _iconButtonFootprint,
            height: _iconButtonFootprint,
          ),
        ],
      ),
    );
  }
}
