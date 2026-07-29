import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../router/routes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/extensions/context_ext.dart';
import '../../utils/spacing.dart';
import '../cubit/app_settings_cubit.dart';
import '../cubit/app_settings_state.dart';

/// Opens the app settings sheet (theme + language + About link).
Future<void> showSettingsSheet(final BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final _) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(top: rh(60)),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(rw(20), rh(12), rw(20), rh(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              verticalSpacing(20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary50.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: AppColors.primary200,
                    ),
                  ),
                  horizontalSpacing(12),
                  Text(
                    'settings.title'.tr(),
                    style: AppTextStyles.font20Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              verticalSpacing(24),
              BlocBuilder<AppSettingsCubit, AppSettingsState>(
                builder:
                    (final BuildContext context, final AppSettingsState state) {
                  final AppSettingsCubit cubit =
                      context.read<AppSettingsCubit>();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel('settings.appearance'.tr()),
                      verticalSpacing(10),
                      _SegmentedSelector<ThemeMode>(
                        value: state.themeMode,
                        segments: <_Segment<ThemeMode>>[
                          _Segment(
                            value: ThemeMode.light,
                            icon: Icons.light_mode_rounded,
                            label: 'settings.theme_light'.tr(),
                          ),
                          _Segment(
                            value: ThemeMode.dark,
                            icon: Icons.dark_mode_rounded,
                            label: 'settings.theme_dark'.tr(),
                          ),
                          _Segment(
                            value: ThemeMode.system,
                            icon: Icons.brightness_auto_rounded,
                            label: 'settings.theme_system'.tr(),
                          ),
                        ],
                        onChanged: cubit.updateTheme,
                      ),
                      verticalSpacing(24),
                      _SectionLabel('settings.language'.tr()),
                      verticalSpacing(10),
                      _SegmentedSelector<String>(
                        value: state.locale.languageCode,
                        segments: <_Segment<String>>[
                          _Segment(
                            value: 'ar',
                            icon: Icons.translate_rounded,
                            label: 'settings.lang_ar'.tr(),
                          ),
                          _Segment(
                            value: 'en',
                            icon: Icons.language_rounded,
                            label: 'settings.lang_en'.tr(),
                          ),
                        ],
                        onChanged: (final String code) => cubit.updateLocale(
                          context,
                          Locale(code),
                        ),
                      ),
                    ],
                  );
                },
              ),
              verticalSpacing(24),
              _SectionLabel('settings.more'.tr()),
              verticalSpacing(10),
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                label: 'settings.about'.tr(),
                onTap: () {
                  Navigator.pop(context);
                  context.pushNamed(Routes.aboutScreen);
                },
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(final BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.font12Bold.copyWith(
        color: context.customColors.textSecondary,
        letterSpacing: 1.1,
      ),
      textAlign: TextAlign.right,
    );
  }
}

class _Segment<T> {
  const _Segment({
    required this.value,
    required this.icon,
    required this.label,
  });

  final T value;
  final IconData icon;
  final String label;
}

class _SegmentedSelector<T> extends StatelessWidget {
  const _SegmentedSelector({
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final T value;
  final List<_Segment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          for (final _Segment<T> segment in segments)
            Expanded(
              child: _SegmentButton<T>(
                segment: segment,
                isSelected: segment.value == value,
                onTap: () => onChanged(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final _Segment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary200 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              segment.icon,
              size: 20,
              color: isSelected ? AppColors.white : colors.iconSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              segment.label,
              style: AppTextStyles.font12Bold.copyWith(
                color: isSelected ? AppColors.white : colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: AppColors.primary200),
            horizontalSpacing(14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.font16SemiBold.copyWith(
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.right,
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
