import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/widgets/custom_text_form_.dart';

/// Small inline editors opened from a field's pencil icon on the detail
/// card — each edits just that one field, instead of routing through the
/// full parcel edit screen. All return `null` when the dialog is dismissed
/// without an explicit save (an empty string IS a valid save, meaning
/// "clear this field").

Future<String?> showTextFieldEditDialog(
  final BuildContext context, {
  required final String title,
  required final String initialValue,
  final TextInputType? keyboardType,
}) async {
  final TextEditingController controller = TextEditingController(
    text: initialValue,
  );
  final String? result = await showDialog<String>(
    context: context,
    builder: (final BuildContext context) => _EditDialogShell(
      title: title,
      onSave: () => Navigator.pop(context, controller.text.trim()),
      child: CustomTextForm(
        hintText: title,
        controller: controller,
        isRTL: true,
        autofocus: true,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == null
            ? null
            : <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.٫]')),
              ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

Future<String?> showDropdownFieldEditDialog(
  final BuildContext context, {
  required final String title,
  required final String? initialValue,
  required final List<String> options,
  final bool allowClear = true,
}) async {
  String? selected = initialValue;
  return showDialog<String>(
    context: context,
    builder: (final BuildContext context) => StatefulBuilder(
      builder: (final BuildContext context, final StateSetter setState) {
        return _EditDialogShell(
          title: title,
          onSave: () => Navigator.pop(context, selected ?? ''),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (allowClear)
                _OptionTile(
                  label: '—',
                  isSelected: selected == null,
                  onTap: () => setState(() => selected = null),
                ),
              for (final String option in options)
                _OptionTile(
                  label: option,
                  isSelected: selected == option,
                  onTap: () => setState(() => selected = option),
                ),
            ],
          ),
        );
      },
    ),
  );
}

Future<bool?> showSwitchFieldEditDialog(
  final BuildContext context, {
  required final String title,
  required final bool initialValue,
}) async {
  bool value = initialValue;
  return showDialog<bool>(
    context: context,
    builder: (final BuildContext context) => StatefulBuilder(
      builder: (final BuildContext context, final StateSetter setState) {
        return _EditDialogShell(
          title: title,
          onSave: () => Navigator.pop(context, value),
          child: Row(
            children: <Widget>[
              Switch(
                value: value,
                onChanged: (final bool v) => setState(() => value = v),
              ),
              Expanded(
                child: Text(
                  value ? 'وراثة' : 'ليست وراثة',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.font14SemiBold.copyWith(
                    color: context.customColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

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
    builder: (final BuildContext context) => _EditDialogShell(
      title: 'المساحة',
      onSave: () => Navigator.pop(context, (
        feddan: _parseLocalizedNum(feddanController.text),
        qirat: _parseLocalizedNum(qiratController.text),
        sahm: _parseLocalizedNum(sahmController.text),
      )),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CustomTextForm(
            hintText: 'فدان',
            controller: feddanController,
            isRTL: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          CustomTextForm(
            hintText: 'قيراط',
            controller: qiratController,
            isRTL: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 10),
          CustomTextForm(
            hintText: 'سهم',
            controller: sahmController,
            isRTL: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    ),
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

class _EditDialogShell extends StatelessWidget {
  const _EditDialogShell({
    required this.title,
    required this.child,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final VoidCallback onSave;

  @override
  Widget build(final BuildContext context) {
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.right),
      content: SingleChildScrollView(child: child),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(onPressed: onSave, child: const Text('حفظ')),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary50.withValues(alpha: 0.3)
              : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary200 : colors.border,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary200 : colors.iconSecondary,
              size: 20,
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
