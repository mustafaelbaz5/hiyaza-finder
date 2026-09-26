import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';

/// Home's default state — shown before the user has typed anything (UI/UX
/// Updates prompt "Change 3"). Home is search-first: it never pre-loads or
/// shows a flat city-wide holdings list, so there is nothing to render here
/// but a prompt to start searching.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 56, color: colors.iconSecondary),
            verticalSpacing(16),
            Text(
              'holdings.search.start_title'.tr(),
              style: AppTextStyles.font18Bold.copyWith(
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            verticalSpacing(8),
            Text(
              'holdings.search.start_subtitle'.tr(),
              style: AppTextStyles.font14Regular.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
