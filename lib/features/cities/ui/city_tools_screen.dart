import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/router/routes.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/screen_header.dart';
import 'widgets/city_info_card.dart';
import 'widgets/city_tool_tile.dart';

class CityToolsScreen extends StatelessWidget {
  const CityToolsScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'cities.tools.title'.tr()),
            const CityInfoCard(),
            Expanded(
              child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  rw(16),
                  rh(18),
                  rw(16),
                  rh(24),
                ),
                children: <Widget>[
                  _SectionHeader(
                    icon: Icons.location_city_outlined,
                    title: 'cities.tools.city_management.title'.tr(),
                  ),
                  verticalSpacing(10),
                  CityToolTile(
                    icon: Icons.holiday_village_rounded,
                    title: 'holdings.basin.title'.tr(),
                    subtitle: 'cities.tools.basins.subtitle'.tr(),
                    onTap: () => context.pushNamed(Routes.basins),
                  ),
                  verticalSpacing(10),
                  CityToolTile(
                    icon: Icons.folder_delete_outlined,
                    title: 'cities.manage.entry'.tr(),
                    subtitle: 'cities.tools.manage_cities.subtitle'.tr(),
                    onTap: () => context.pushNamed(Routes.manageCities),
                  ),
                  verticalSpacing(10),
                  CityToolTile(
                    icon: Icons.file_download_outlined,
                    title: 'holdings.export.title'.tr(),
                    subtitle: 'cities.tools.export.subtitle'.tr(),
                    onTap: () => context.pushNamed(Routes.export),
                  ),
                  verticalSpacing(24),
                  _SectionHeader(
                    icon: Icons.tune_rounded,
                    title: 'cities.tools.data_operations.title'.tr(),
                  ),
                  verticalSpacing(10),
                  CityToolTile(
                    icon: Icons.build_circle_outlined,
                    title: 'cities.tools.helper_tools.title'.tr(),
                    subtitle: 'cities.tools.helper_tools.subtitle'.tr(),
                    onTap: () => context.pushNamed(Routes.helperTools),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Row(
      textDirection: Directionality.of(context),
      children: <Widget>[
        Icon(icon, size: 17, color: colors.textSecondary),
        horizontalSpacing(7),
        Text(
          title,
          style: AppTextStyles.font12Bold.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}
