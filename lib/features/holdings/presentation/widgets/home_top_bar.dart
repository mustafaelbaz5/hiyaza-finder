import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/config/app_config.dart';
import 'package:hiyaza_finder/core/di/dependency_injection.dart';
import 'package:hiyaza_finder/core/networking/connection_quality_service.dart';
import 'package:hiyaza_finder/core/router/routes.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/pending_syncs_sheet.dart';
import 'package:hiyaza_finder/features/holdings/presentation/widgets/top_bar_icon_button.dart';
import 'package:hiyaza_finder/features/sync/domain/entities/sync_operation.dart';
import 'package:hiyaza_finder/features/sync/domain/services/sync_runner.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.onSettings,
  });

  final VoidCallback onSettings;

  /// Matches [TopBarIconButton]'s footprint so the centered title/brand
  /// column stays visually centered.
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
          horizontalSpacing(8),
          const _ConnectionQualityBadge(),
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
          TopBarIconButton(
            icon: Icons.build_outlined,
            tooltip: 'cities.tools.entry'.tr(),
            onTap: () => context.pushNamed(Routes.cityTools),
          ),
          horizontalSpacing(8),
          const _PendingSyncsButton(),
        ],
      ),
    );
  }
}

/// Shows the device's current connectivity at a glance — a green wifi icon
/// when [ConnectionQuality.strong], an amber wifi icon with a small dot
/// badge when [ConnectionQuality.weak] (connected, but the reachability
/// check is responding slowly), and a red wifi-off icon when
/// [ConnectionQuality.offline]. Tapping it shows the same classification as
/// a tooltip/snackbar, since a fixed icon alone doesn't explain *why* it
/// changed color.
class _ConnectionQualityBadge extends StatelessWidget {
  const _ConnectionQualityBadge();

  @override
  Widget build(final BuildContext context) {
    final ConnectionQualityService service = getIt<ConnectionQualityService>();

    return SizedBox(
      width: HomeTopBar._iconButtonFootprint,
      height: HomeTopBar._iconButtonFootprint,
      child: StreamBuilder<ConnectionQuality>(
        stream: service.onQualityChanged,
        initialData: service.current,
        builder: (final BuildContext context, final snapshot) {
          final ConnectionQuality quality = snapshot.data ?? ConnectionQuality.strong;
          final (IconData icon, Color color, String label) = switch (quality) {
            ConnectionQuality.strong => (
                Icons.wifi_rounded,
                AppColors.green200,
                'connectivity.strong'.tr(),
              ),
            ConnectionQuality.weak => (
                Icons.wifi_rounded,
                AppColors.amber300,
                'connectivity.weak'.tr(),
              ),
            ConnectionQuality.offline => (
                Icons.wifi_off_rounded,
                AppColors.red200,
                'connectivity.offline'.tr(),
              ),
          };

          return Tooltip(
            message: label,
            child: InkWell(
              onTap: () => context.showSnackBar(label),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.customColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Opens the pending/failed-syncs sheet (`REFACTOR_ROADMAP.md` Phase 9 #9)
/// — a badge shows the queue length whenever it's non-empty, red once any
/// operation has failed at least once (`attempts > 0`) so a stuck write is
/// visible without the user having to open the sheet to notice.
class _PendingSyncsButton extends StatelessWidget {
  const _PendingSyncsButton();

  @override
  Widget build(final BuildContext context) {
    final SyncRunner syncRunner = getIt<SyncRunner>();

    return SizedBox(
      width: HomeTopBar._iconButtonFootprint,
      height: HomeTopBar._iconButtonFootprint,
      child: StreamBuilder<List<SyncOperation>>(
        stream: syncRunner.onQueueChanged,
        initialData: syncRunner.operations,
        builder: (final BuildContext context, final snapshot) {
          final List<SyncOperation> ops = snapshot.data ?? const <SyncOperation>[];
          final bool hasFailed = ops.any((final SyncOperation o) => o.attempts > 0);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              TopBarIconButton(
                icon: Icons.sync_rounded,
                tooltip: 'sync.status.tap_to_sync'.tr(),
                onTap: () => showPendingSyncsSheet(context),
              ),
              if (ops.isNotEmpty)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: hasFailed ? AppColors.red200 : AppColors.primary200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${ops.length}',
                      style: AppTextStyles.font12Bold.copyWith(color: Colors.white),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
