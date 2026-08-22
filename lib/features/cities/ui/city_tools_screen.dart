import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/router/routes.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/screen_header.dart';

/// Entry point for city-scoped maintenance actions: which cities are
/// downloaded, the missing-رقم-الحيازة worklist, and per-city نوع الزرع
/// options. Consolidates every city-level action that previously lived
/// scattered in the settings sheet into one screen.
class CityToolsScreen extends StatefulWidget {
  const CityToolsScreen({super.key});

  @override
  State<CityToolsScreen> createState() => _CityToolsScreenState();
}

class _CityToolsScreenState extends State<CityToolsScreen> {
  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(title: 'cities.tools.title'.tr()),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: rw(16))
                    .copyWith(bottom: rh(24)),
                children: [
                  _ToolTile(
                    icon: Icons.folder_delete_outlined,
                    title: 'cities.manage.entry'.tr(),
                    subtitle: 'cities.tools.manage_cities.subtitle'.tr(),
                    onTap: () => context.pushNamed(Routes.manageCities),
                  ),
                  verticalSpacing(10),
                  _ToolTile(
                    icon: Icons.assignment_late_outlined,
                    title: 'cities.tools.missing_holding_id.title'.tr(),
                    subtitle: 'cities.tools.missing_holding_id.subtitle'.tr(),
                    onTap: () => context.pushNamed(Routes.missingHoldingId),
                  ),
                  verticalSpacing(10),
                  _ToolTile(
                    icon: Icons.grass_outlined,
                    title: 'cities.tools.crop_types.title'.tr(),
                    subtitle: 'cities.tools.crop_types.subtitle'.tr(),
                    onTap: () => context.pushNamed(Routes.cropTypeSettings),
                  ),
                  verticalSpacing(10),
                  _ToolTile(
                    icon: Icons.file_download_outlined,
                    title: 'holdings.export.title'.tr(),
                    subtitle: 'cities.tools.export.subtitle'.tr(),
                    onTap: () => context.pushNamed(Routes.export),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(rw(16)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary50.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary200),
            ),
            horizontalSpacing(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTextStyles.font16SemiBold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.font12Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: colors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
