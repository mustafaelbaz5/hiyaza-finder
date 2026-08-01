import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiyaza_finder/features/holdings/ui/widgets/tile_icon_button.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// A compact label+value tile with copy (and optional inline-edit) icons.
/// Sized to sit in a responsive wrap/grid rather than a single full-width
/// list, so a card with many fields stays short.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    this.onEdit,
    this.placeholder,
  });

  final String label;
  final String? value;

  /// Shown as a small pencil icon beside the copy icon when non-null — lets
  /// the caller open an inline editor scoped to just this field.
  final VoidCallback? onEdit;

  /// Overrides [emptyPlaceholder] for this one field (e.g. كود الحوض shows
  /// "-1" specifically, while every other empty field shows "-").
  final String? placeholder;

  /// Placeholder shown (and copied) when the underlying value is empty —
  /// the copy action stays active either way.
  static const String emptyPlaceholder = '-';

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String displayValue =
        (value == null || value!.trim().isEmpty) ? (placeholder ?? emptyPlaceholder) : value!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  displayValue,
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
          if (onEdit != null)
            TileIconButton(icon: Icons.edit_rounded, onTap: onEdit!, tooltip: 'تعديل'),
          TileIconButton(
            icon: Icons.copy_rounded,
            onTap: () => _copy(context, displayValue),
            tooltip: 'نسخ',
          ),
        ],
      ),
    );
  }

  Future<void> _copy(final BuildContext context, final String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      HapticFeedback.lightImpact();
      context.showSuccessSnackBar('holdings.detail.copied'.tr());
    }
  }
}
