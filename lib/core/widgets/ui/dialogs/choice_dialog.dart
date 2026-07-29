import 'package:flutter/material.dart';

import '../../../themes/app_colors.dart';
import '../../../themes/app_text_styles.dart';
import '../../../utils/extensions/context_ext.dart';
import '../../../utils/spacing.dart';

/// One selectable option in [showChoiceDialog].
class ChoiceOption<T> {
  const ChoiceOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A choice made in [showChoiceDialog] — kept distinct from the dialog
/// returning `null` outright (dismissed without any choice, meaning "no
/// change"), since an explicit "cleared" selection is itself a valid
/// choice that also needs to be told apart from "unchanged".
class ChoiceDialogResult<T> {
  const ChoiceDialogResult._(this.value, this.isClear);
  const ChoiceDialogResult.value(final T value) : this._(value, false);
  const ChoiceDialogResult.clear() : this._(null, true);

  final T? value;
  final bool isClear;
}

/// A reusable single-choice dialog, styled consistently with
/// [CustomAppDialog] — tapping an option selects it and closes the dialog
/// immediately, since picking an option IS the action; there's no separate
/// save/cancel step to get right or forget. Dismissing (barrier tap / back
/// button) returns `null`, meaning "no change".
Future<ChoiceDialogResult<T>?> showChoiceDialog<T>(
  final BuildContext context, {
  required final String title,
  required final List<ChoiceOption<T>> options,
  final T? selected,
  final String? clearLabel,
}) {
  return showDialog<ChoiceDialogResult<T>>(
    context: context,
    builder: (final BuildContext context) => _ChoiceDialog<T>(
      title: title,
      options: options,
      selected: selected,
      clearLabel: clearLabel,
    ),
  );
}

class _ChoiceDialog<T> extends StatelessWidget {
  const _ChoiceDialog({
    required this.title,
    required this.options,
    required this.selected,
    required this.clearLabel,
  });

  final String title;
  final List<ChoiceOption<T>> options;
  final T? selected;
  final String? clearLabel;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: rw(32), vertical: rh(24)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rr(16))),
      backgroundColor: colors.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: rh(440)),
        child: Padding(
          padding: EdgeInsets.all(rw(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.font18Bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              verticalSpacing(16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (clearLabel != null)
                      _ChoiceTile(
                        label: clearLabel!,
                        isSelected: selected == null,
                        icon: Icons.remove_circle_outline_rounded,
                        onTap: () =>
                            Navigator.pop(context, ChoiceDialogResult<T>.clear()),
                      ),
                    for (final ChoiceOption<T> option in options)
                      _ChoiceTile(
                        label: option.label,
                        isSelected: selected == option.value,
                        icon: option.icon,
                        onTap: () => Navigator.pop(
                          context,
                          ChoiceDialogResult<T>.value(option.value),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary50.withValues(alpha: 0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary200 : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : (icon ?? Icons.radio_button_off_rounded),
              size: 20,
              color: isSelected ? AppColors.primary200 : colors.iconSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: AppTextStyles.font14SemiBold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
