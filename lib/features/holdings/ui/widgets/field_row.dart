import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tile_icon_button.dart';


import '../../../../core/themes/app_colors.dart';
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
    this.isModified = false,
  });

  final String label;
  final String? value;

  /// Shown as a small pencil icon beside the copy icon when non-null — lets
  /// the caller open an inline editor scoped to just this field.
  final VoidCallback? onEdit;

  /// Overrides [emptyPlaceholder] for this one field (e.g. كود الحوض shows
  /// "-1" specifically, while every other empty field shows "-").
  final String? placeholder;

  /// Whether the current value differs from the field's original value in
  /// this edit session — highlights the tile (amber border + "تم التعديل"
  /// badge) so unsaved changes are obvious before the record is saved. The
  /// caller decides what "original" means (see `FieldChangeTracker`); this
  /// widget only renders the flag, it never compares values itself.
  final bool isModified;

  /// Placeholder shown (and copied) when the underlying value is empty —
  /// the copy action stays active either way.
  static const String emptyPlaceholder = '-';

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String displayValue = (value == null || value!.trim().isEmpty)
        ? (placeholder ?? emptyPlaceholder)
        : value!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      const _ModifiedBadge(),
                    ],
                  ],
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
          Wrap(
            spacing: 4,
            children: <Widget>[
              if (onEdit != null)
                TileIconButton(
                  icon: Icons.edit_rounded,
                  onTap: onEdit!,
                  tooltip: 'holdings.field.edit_tooltip'.tr(),
                ),
              TileIconButton(
                icon: Icons.copy_rounded,
                onTap: () => _copy(context, displayValue),
                tooltip: 'holdings.field.copy_tooltip'.tr(),
              ),
            ],
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

/// Tiny "تم التعديل" pill shown beside a field's label when
/// [FieldRow.isModified]/[ToggleFieldRow.isModified] is true. Kept as one
/// shared widget (rather than inlined in each field type) so both stay
/// visually identical and only need updating in one place.
class _ModifiedBadge extends StatelessWidget {
  const _ModifiedBadge();

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
    );
  }
}
