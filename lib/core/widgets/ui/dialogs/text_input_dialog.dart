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
}) async {
  final TextEditingController controller = TextEditingController(
    text: initialValue,
  );

  final String? result = await showDialog<String>(
    context: context,
    builder: (final BuildContext context) {
      final colors = context.customColors;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: rw(32)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rr(16)),
        ),
        backgroundColor: colors.surface,
        child: Padding(
          padding: EdgeInsets.all(rw(24)),
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
              CustomTextForm(
                hintText: title,
                controller: controller,
                isRTL: true,
                autofocus: true,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
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
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  controller.dispose();
  return result;
}
