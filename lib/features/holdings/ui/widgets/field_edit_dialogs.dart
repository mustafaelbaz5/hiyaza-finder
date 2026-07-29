import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';

/// المساحة needs three related numbers at once, so — unlike the single-value
/// fields handled by the generic `showTextInputDialog`/`showChoiceDialog` in
/// `core/widgets/ui/dialogs` — it stays a bespoke composite dialog, styled
/// to match them.
typedef AreaEditResult = ({double? feddan, double? qirat, double? sahm});

Future<AreaEditResult?> showAreaFieldEditDialog(
  final BuildContext context, {
  required final double? feddan,
  required final double? qirat,
  required final double? sahm,
}) async {
  final TextEditingController feddanController = TextEditingController(
    text: _numToText(feddan),
  );
  final TextEditingController qiratController = TextEditingController(
    text: _numToText(qirat),
  );
  final TextEditingController sahmController = TextEditingController(
    text: _numToText(sahm),
  );

  final AreaEditResult? result = await showDialog<AreaEditResult>(
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
                'المساحة',
                textAlign: TextAlign.center,
                style: AppTextStyles.font18Bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              verticalSpacing(16),
              CustomTextForm(
                hintText: 'فدان',
                controller: feddanController,
                isRTL: true,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              verticalSpacing(10),
              CustomTextForm(
                hintText: 'قيراط',
                controller: qiratController,
                isRTL: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              verticalSpacing(10),
              CustomTextForm(
                hintText: 'سهم',
                controller: sahmController,
                isRTL: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                      onPressed: () => Navigator.pop(context, (
                        feddan: _parseLocalizedNum(feddanController.text),
                        qirat: _parseLocalizedNum(qiratController.text),
                        sahm: _parseLocalizedNum(sahmController.text),
                      )),
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

  feddanController.dispose();
  qiratController.dispose();
  sahmController.dispose();
  return result;
}

String _numToText(final double? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

double? _parseLocalizedNum(final String raw) {
  const String arabic = '٠١٢٣٤٥٦٧٨٩';
  const String persian = '۰۱۲۳۴۵۶۷۸۹';
  final StringBuffer out = StringBuffer();
  for (final String ch in raw.split('')) {
    final int ai = arabic.indexOf(ch);
    final int pi = persian.indexOf(ch);
    if (ai >= 0) {
      out.write(ai);
    } else if (pi >= 0) {
      out.write(pi);
    } else {
      out.write(ch);
    }
  }
  final String s = out.toString().trim().replaceAll('٫', '.');
  if (s.isEmpty) return null;
  return double.tryParse(s);
}
