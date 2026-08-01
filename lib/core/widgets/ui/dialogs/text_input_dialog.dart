import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../themes/app_text_styles.dart';
import '../../../utils/extensions/context_ext.dart';
import '../../../utils/spacing.dart';
import '../../custom_text_button.dart';
import '../../custom_text_form_.dart';

/// A reusable single-text-field input dialog, styled consistently with
/// [CustomAppDialog]. Unlike [showChoiceDialog], typing needs an explicit
/// confirm step, so this keeps Save/Cancel buttons. Returns the trimmed
/// text, or `null` if dismissed/cancelled — an empty string IS a valid
/// save, meaning "clear this field".
Future<String?> showTextInputDialog(
  final BuildContext context, {
  required final String title,
  required final String initialValue,
  final TextInputType? keyboardType,
  final List<TextInputFormatter>? inputFormatters,
}) {
  return showDialog<String>(
    context: context,
    builder: (final BuildContext context) => _TextInputDialog(
      title: title,
      initialValue: initialValue,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialValue,
    required this.keyboardType,
    required this.inputFormatters,
  });

  final String title;
  final String initialValue;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  // Disposing here — rather than right after showDialog's Future resolves
  // — matters: this only runs once Flutter actually unmounts the dialog,
  // i.e. after its pop/exit animation finishes. Disposing immediately on
  // pop instead races that animation (the dialog is still being painted
  // for another frame or two) and throws "used after being disposed".
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              widget.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.font18Bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            verticalSpacing(16),
            CustomTextForm(
              hintText: widget.title,
              controller: _controller,
              isRTL: true,
              autofocus: true,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
            ),
            verticalSpacing(20),
            Row(
              children: [
                Expanded(
                  child: CustomTextButton.outlined(
                    text: 'إلغاء',
                    size: CustomButtonSize.small,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                horizontalSpacing(8),
                Expanded(
                  child: CustomTextButton(
                    text: 'حفظ',
                    size: CustomButtonSize.small,
                    onPressed: () => Navigator.pop(context, _controller.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
