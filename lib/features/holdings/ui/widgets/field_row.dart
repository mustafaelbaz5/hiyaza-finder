import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// Label + value row with a copy-to-clipboard icon. Values are large and
/// bold per the sunlight-readability requirement (base ≥18sp, bold values).
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    this.showDivider = true,
    this.onEdit,
  });

  final String label;
  final String? value;
  final bool showDivider;

  /// Shown as a pencil icon beside the copy icon when non-null — lets the
  /// caller open an inline editor scoped to just this field.
  final VoidCallback? onEdit;

  /// Placeholder shown (and copied) when the underlying value is empty —
  /// the copy action stays active either way.
  static const String emptyPlaceholder = '-1';

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String displayValue =
        (value == null || value!.trim().isEmpty) ? emptyPlaceholder : value!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.font14Regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayValue,
                      style: AppTextStyles.font18Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: AppColors.primary200,
                  ),
                  tooltip: 'تعديل',
                ),
              IconButton(
                onPressed: () => _copy(context, displayValue),
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 22,
                  color: AppColors.primary200,
                ),
                tooltip: 'نسخ',
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, thickness: 1, color: colors.divider),
      ],
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
