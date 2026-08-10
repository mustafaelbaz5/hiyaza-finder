import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/dependency_injection.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/screen_header.dart';
import '../../../../core/widgets/ui/dialogs/text_input_dialog.dart';
import '../../../holdings/data/repository/holdings_repository.dart';
import '../../domain/entities/city.dart';
import '../../domain/repositories/city_repository.dart';

/// Entry point for city-scoped maintenance actions: which cities are
/// downloaded, the missing-رقم-الحيازة worklist, per-city نوع الزرع options,
/// and the city's reference code. Consolidates every city-level action that
/// previously lived scattered in the settings sheet into one screen.
class CityToolsScreen extends StatefulWidget {
  const CityToolsScreen({super.key});

  @override
  State<CityToolsScreen> createState() => _CityToolsScreenState();
}

class _CityToolsScreenState extends State<CityToolsScreen> {
  final CityRepository _cityRepository = getIt<CityRepository>();
  final String? _cityId = getIt<HoldingsRepository>().activeCityId;

  bool _isLoadingCode = false;

  Future<void> _editCityCode() async {
    final String? cityId = _cityId;
    if (cityId == null) return;

    setState(() => _isLoadingCode = true);
    String initialValue = '';
    bool fetchFailed = false;
    try {
      final City city = await _cityRepository.fetchCity(cityId);
      initialValue = city.code ?? '';
    } catch (_) {
      fetchFailed = true;
    }
    if (!mounted) return;
    setState(() => _isLoadingCode = false);
    if (fetchFailed) {
      context.showErrorSnackBar('errors.unknown'.tr());
      return;
    }

    final String? value = await showTextInputDialog(
      context,
      title: 'cities.tools.city_code.edit_title'.tr(),
      initialValue: initialValue,
    );
    if (value == null || !mounted) return;

    final String trimmed = value.trim();
    try {
      await _cityRepository.updateCityCode(
        cityId,
        trimmed.isEmpty ? null : trimmed,
      );
      if (!mounted) return;
      context.showSuccessSnackBar('cities.tools.city_code.saved'.tr());
    } catch (_) {
      if (!mounted) return;
      context.showErrorSnackBar('errors.unknown'.tr());
    }
  }

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
                  if (_cityId != null) ...[
                    verticalSpacing(10),
                    _ToolTile(
                      icon: Icons.qr_code_2_rounded,
                      title: 'cities.tools.city_code.title'.tr(),
                      subtitle: 'cities.tools.city_code.subtitle'.tr(),
                      isLoading: _isLoadingCode,
                      onTap: _editCityCode,
                    ),
                  ],
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
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: isLoading ? null : onTap,
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
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
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
