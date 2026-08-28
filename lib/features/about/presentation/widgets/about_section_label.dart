import 'package:flutter/material.dart';

import '../../../../core/themes/app_text_styles.dart';

class AboutSectionLabel extends StatelessWidget {
  final String label;

  const AboutSectionLabel(this.label, {super.key});

  @override
  Widget build(final BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.font12Bold.copyWith(
        letterSpacing: 1.2,
      ),
    );
  }
}
