import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';
import '../../data/model/parcel.dart';

/// Adds one ملاحظة — either typed free-text or picked from
/// [Parcel.notesOptions]'s common list. Returns the chosen/typed text
/// (trimmed), or `null` if dismissed without adding anything.
Future<String?> showAddNoteDialog(final BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (final BuildContext context) => const _AddNoteDialog(),
  );
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog();

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitFreeText() {
    final String trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.pop(context, trimmed);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: rw(32)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rr(16))),
      backgroundColor: colors.surface,
      child: Padding(
        padding: EdgeInsets.all(rw(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'holdings.notes_field.add_title'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.font18Bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            verticalSpacing(16),
            CustomTextForm(
              hintText: 'holdings.notes_field.free_text_hint'.tr(),
              controller: _controller,
              isRTL: true,
              autofocus: true,
            ),
            verticalSpacing(12),
            Row(
              children: [
                Expanded(
                  child: CustomTextButton.outlined(
                    text: 'app_dialogs.cancel'.tr(),
                    size: CustomButtonSize.small,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                horizontalSpacing(8),
                Expanded(
                  child: CustomTextButton(
                    text: 'app_dialogs.save'.tr(),
                    size: CustomButtonSize.small,
                    onPressed: _submitFreeText,
                  ),
                ),
              ],
            ),
            verticalSpacing(16),
            Text(
              'holdings.notes_field.quick_list_title'.tr(),
              style: AppTextStyles.font12Bold.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
            verticalSpacing(8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: rh(220)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final String option in Parcel.notesOptions)
                      if (option != Parcel.notesOtherOption)
                        _QuickNoteTile(
                          label: option,
                          onTap: () => Navigator.pop(context, option),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickNoteTile extends StatelessWidget {
  const _QuickNoteTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Text(
          label,
          style: AppTextStyles.font14Regular.copyWith(
            color: colors.textPrimary,
          ),
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}
