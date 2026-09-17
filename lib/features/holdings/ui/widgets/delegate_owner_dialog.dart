import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';

/// Prompts for the new اسم المالك when مفوض is enabled — must differ from
/// اسم الحائز (validated inline, not just rejected silently). Returns the
/// trimmed name, or `null` if dismissed without confirming.
Future<String?> showDelegateOwnerDialog(
  final BuildContext context, {
  required final String holderName,
}) {
  return showDialog<String>(
    context: context,
    builder: (final BuildContext context) =>
        _DelegateOwnerDialog(holderName: holderName),
  );
}

class _DelegateOwnerDialog extends StatefulWidget {
  const _DelegateOwnerDialog({required this.holderName});

  final String holderName;

  @override
  State<_DelegateOwnerDialog> createState() => _DelegateOwnerDialogState();
}

class _DelegateOwnerDialogState extends State<_DelegateOwnerDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final String trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = 'holdings.delegate.name_required'.tr());
      return;
    }
    if (trimmed == widget.holderName.trim()) {
      setState(() => _errorText = 'holdings.delegate.name_must_differ'.tr());
      return;
    }
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
              'holdings.delegate.dialog_title'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.font18Bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            verticalSpacing(8),
            Text(
              'holdings.delegate.dialog_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.font12Regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            verticalSpacing(16),
            CustomTextForm(
              hintText: 'holdings.fields.owner_name'.tr(),
              controller: _controller,
              isRTL: true,
              autofocus: true,
              onChanged: (final _) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            if (_errorText != null) ...[
              verticalSpacing(6),
              Text(
                _errorText!,
                style: AppTextStyles.font12Regular.copyWith(
                  color: colors.error,
                ),
                textAlign: TextAlign.right,
              ),
            ],
            verticalSpacing(20),
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
                    onPressed: _confirm,
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
