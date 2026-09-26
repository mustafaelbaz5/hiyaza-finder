import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// Whether [AddRecordScreen] is adding a brand-new person, or a new holding
/// for a person who already exists (APP_UPDATES_CLAUDE.md § 2). Only shown
/// when the screen is reached from a generic "+" entry point (Home/Basin) —
/// reaching it from Detail Screen's "+ إضافة قطعة" already implies existing
/// person and skips this toggle entirely.
enum AddMode { newPerson, existingPerson }

class AddModeToggle extends StatelessWidget {
  const AddModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final AddMode mode;
  final ValueChanged<AddMode> onChanged;

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
        children: [
          Expanded(
            child: _Segment(
              label: 'holdings.add.mode_new_person'.tr(),
              isSelected: mode == AddMode.newPerson,
              onTap: () => onChanged(AddMode.newPerson),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'holdings.add.mode_existing_person'.tr(),
              isSelected: mode == AddMode.existingPerson,
              onTap: () => onChanged(AddMode.existingPerson),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
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
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.font14Bold.copyWith(
            color: isSelected ? AppColors.white : colors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
