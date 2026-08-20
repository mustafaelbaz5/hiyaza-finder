import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_colors.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';


/// A boolean-valued sibling to [FieldRow] — same tile styling, but the
/// value is flipped directly with a [Switch] instead of opening a dialog,
/// since a two-state choice doesn't need a confirm step.
class ToggleFieldRow extends StatelessWidget {
  const ToggleFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.activeLabel,
    this.inactiveLabel,
    this.isModified = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? activeLabel;
  final String? inactiveLabel;

  /// See [FieldRow.isModified] — same meaning, same badge.
  final bool isModified;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String stateText = value
        ? (activeLabel ?? 'app_dialogs.yes'.tr())
        : (inactiveLabel ?? 'app_dialogs.no'.tr());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color:
            isModified ? AppColors.amber300.withValues(alpha: 0.08) : colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isModified ? AppColors.amber300 : colors.border,
          width: isModified ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.font12Regular.copyWith(
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isModified) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.amber300.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'holdings.field.modified_badge'.tr(),
                          style: AppTextStyles.font12Bold.copyWith(
                            color: AppColors.amber300,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stateText,
                  style: AppTextStyles.font14SemiBold.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
