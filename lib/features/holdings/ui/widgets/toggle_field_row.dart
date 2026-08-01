import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/field_row.dart';

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
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? activeLabel;
  final String? inactiveLabel;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String stateText = value ? (activeLabel ?? 'نعم') : (inactiveLabel ?? 'لا');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.font12Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
