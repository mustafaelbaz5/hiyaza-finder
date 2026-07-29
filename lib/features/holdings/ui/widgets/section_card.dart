import 'package:flutter/material.dart';
import 'package:hiyaza_finder/core/themes/app_text_styles.dart';
import 'package:hiyaza_finder/core/utils/extensions/context_ext.dart';
import 'package:hiyaza_finder/core/utils/spacing.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return Container(
      padding: EdgeInsets.all(rw(14)),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTextStyles.font16Bold.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.font12Regular.copyWith(
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
          verticalSpacing(12),
          child,
        ],
      ),
    );
  }
}
