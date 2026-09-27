import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../data/local/jazla_preferences.dart';

Future<JazlaSort?> showJazlaSortSheet(
  final BuildContext context, {
  required final JazlaSort selected,
}) {
  return showModalBottomSheet<JazlaSort>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) =>
        _JazlaSortSheet(selected: selected),
  );
}

class _JazlaSortSheet extends StatelessWidget {
  const _JazlaSortSheet({required this.selected});

  final JazlaSort selected;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(rw(20), rh(12), rw(20), rh(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary200.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.sort_rounded,
                        color: AppColors.primary200),
                  ),
                  horizontalSpacing(10),
                  Expanded(
                    child: Text(
                      'jazla.sort.title'.tr(),
                      textAlign: TextAlign.right,
                      style: AppTextStyles.font18Bold
                          .copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              verticalSpacing(14),
              ...JazlaSort.values.map(
                (final JazlaSort sort) => _SortOption(
                  sort: sort,
                  selected: sort == selected,
                  onTap: () => Navigator.pop(context, sort),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.sort,
    required this.selected,
    required this.onTap,
  });

  final JazlaSort sort;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (sort) {
        JazlaSort.newest => Icons.schedule_rounded,
        JazlaSort.updated => Icons.update_rounded,
        JazlaSort.name => Icons.sort_by_alpha_rounded,
        JazlaSort.parcelCount => Icons.format_list_numbered_rounded,
      };

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primary200.withValues(alpha: 0.12)
            : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  _icon,
                  color: selected ? AppColors.primary200 : colors.iconSecondary,
                ),
                horizontalSpacing(12),
                Expanded(
                  child: Text(
                    'jazla.sort.${sort.name}'.tr(),
                    style: AppTextStyles.font14SemiBold.copyWith(
                      color:
                          selected ? AppColors.primary200 : colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primary200 : colors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
