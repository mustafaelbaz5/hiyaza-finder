import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/custom_text_button.dart';
import '../../../../core/widgets/custom_text_form_.dart';

/// Shown once per newly-loaded workbook: lets the user confirm or correct
/// the اسم الجمعية auto-derived from the file name before it's stamped onto
/// every parcel. Dismissing without an explicit choice keeps [derivedName]
/// as-is rather than leaving the field unset.
Future<String> showAssociationNameSheet(
  final BuildContext context, {
  required final String derivedName,
}) async {
  final String? result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) =>
        _AssociationNameSheet(derivedName: derivedName),
  );
  return result ?? derivedName;
}

class _AssociationNameSheet extends StatefulWidget {
  const _AssociationNameSheet({required this.derivedName});

  final String derivedName;

  @override
  State<_AssociationNameSheet> createState() => _AssociationNameSheetState();
}

class _AssociationNameSheetState extends State<_AssociationNameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.derivedName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final String text = _controller.text.trim();
    Navigator.pop(context, text.isEmpty ? widget.derivedName : text);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              verticalSpacing(12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              verticalSpacing(16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: rw(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'holdings.association.title'.tr(),
                      style: AppTextStyles.font18Bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    verticalSpacing(6),
                    Text(
                      'holdings.association.subtitle'.tr(),
                      style: AppTextStyles.font14Regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    verticalSpacing(16),
                    CustomTextForm(
                      hintText: 'holdings.association.hint'.tr(),
                      controller: _controller,
                      isRTL: true,
                      autofocus: true,
                    ),
                    verticalSpacing(16),
                    CustomTextButton(
                      text: 'holdings.association.confirm'.tr(),
                      onPressed: _confirm,
                    ),
                    verticalSpacing(24),
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
