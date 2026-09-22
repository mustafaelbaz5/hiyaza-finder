import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/extensions/context_ext.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/widgets/screen_header.dart';
import '../../holdings/ui/widgets/notes_settings_sheet.dart';
import '../../holdings/ui/widgets/section_card.dart';
import 'widgets/city_tool_tile.dart';

class HelperToolsScreen extends StatelessWidget {
  const HelperToolsScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(title: 'cities.tools.helper_tools.title'.tr()),
            Expanded(
              child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  rw(16),
                  rh(18),
                  rw(16),
                  rh(24),
                ),
                children: <Widget>[
                  SectionCard(
                    title: 'cities.tools.helper_tools.title'.tr(),
                    subtitle: 'cities.tools.helper_tools.subtitle'.tr(),
                    child: Column(
                      children: <Widget>[
                        CityToolTile(
                          embedded: true,
                          icon: Icons.dashboard_customize_outlined,
                          title: 'holdings.bulk_edit.entry_pill'.tr(),
                          subtitle: 'cities.tools.bulk_edit.subtitle'.tr(),
                          onTap: () => context.pushNamed(Routes.fileStatus),
                        ),
                        Divider(height: 1, color: colors.border),
                        CityToolTile(
                          embedded: true,
                          icon: Icons.grass_outlined,
                          title: 'cities.tools.crop_types.title'.tr(),
                          subtitle: 'cities.tools.crop_types.subtitle'.tr(),
                          onTap: () =>
                              context.pushNamed(Routes.cropTypeSettings),
                        ),
                        Divider(height: 1, color: colors.border),
                        CityToolTile(
                          embedded: true,
                          icon: Icons.sticky_note_2_outlined,
                          title: 'cities.tools.notes_settings.title'.tr(),
                          subtitle: 'cities.tools.notes_settings.subtitle'.tr(),
                          onTap: () => showNotesSettingsSheet(context),
                        ),
                        Divider(height: 1, color: colors.border),
                        CityToolTile(
                          embedded: true,
                          icon: Icons.assignment_late_outlined,
                          title: 'cities.tools.missing_holding_id.title'.tr(),
                          subtitle:
                              'cities.tools.missing_holding_id.subtitle'.tr(),
                          onTap: () =>
                              context.pushNamed(Routes.missingHoldingId),
                        ),
                      ],
                    ),
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
