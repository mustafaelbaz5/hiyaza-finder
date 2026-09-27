import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/widgets/custom_text_form_.dart';

class JazlaSearchBar extends StatelessWidget {
  const JazlaSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return CustomTextForm(
      hintText: 'jazla.add_sheet.search_hint'.tr(),
      controller: controller,
      focusNode: focusNode,
      isRTL: true,
      borderColor: colors.border,
      backgroundColor: colors.background,
      borderRadius: 14,
      prefixIcon: Icon(Icons.search_rounded, color: colors.iconSecondary),
      onChanged: onChanged,
    );
  }
}
