import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/config/app_config.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/top_bar_icon_button.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.onSettings,
    this.onRefresh,
    this.isRefreshing = false,
  });

  final VoidCallback onSettings;

  /// Re-downloads the active city's latest data (after flushing any queued
  /// local edits first) — `null` until a city is actually loaded, since
  /// there's nothing to refresh before then.
  final VoidCallback? onRefresh;

  /// Whether a refresh triggered by [onRefresh] is currently in flight —
  /// swaps the icon for a spinner and (via `onRefresh` itself being made
  /// re-entrant-safe by the caller) prevents a second tap from starting a
  /// concurrent refresh.
  final bool isRefreshing;

  /// Matches [TopBarIconButton]'s footprint so the centered title/brand
  /// column stays visually centered without a second icon button on the
  /// trailing side (the history button/screen was retired along with the
  /// rest of the Excel-file flow — APP_PLAN.md Phase 5).
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
          if (onRefresh == null)
            const SizedBox(
              width: _iconButtonFootprint,
              height: _iconButtonFootprint,
            )
          else
            SizedBox(
              width: _iconButtonFootprint,
              height: _iconButtonFootprint,
              child: isRefreshing
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary200,
                        ),
                      ),
                    )
                  : TopBarIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'cities.stale_banner.refresh'.tr(),
                      onTap: onRefresh!,
                    ),
            ),
        ],
      ),
    );
  }
}
