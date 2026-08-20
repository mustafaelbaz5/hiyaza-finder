import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';
import '../../../../core/widgets/app_back_button.dart';

/// The top bar (back button + title) and, when adding a parcel for an
/// existing person, the "إضافة قطعة أرض جديدة لـ {name}" banner —
/// [AddRecordScreen]'s non-form chrome, extracted so the screen's own
/// build method is just the form itself.
class AddRecordHeader extends StatelessWidget {
  const AddRecordHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.forPersonName,
  });

  final String title;
  final VoidCallback onBack;

  /// Non-null only for the "add parcel for existing person" flow — the
  /// holder name shown in the "for {name}" banner.
  final String? forPersonName;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        verticalSpacing(16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: rw(16)),
          child: Row(
            children: [
              AppBackButton(onTap: onBack),
              horizontalSpacing(12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.font20Bold.copyWith(
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        if (forPersonName != null) ...[
          verticalSpacing(12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: rw(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.blue200.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'holdings.add.for_person'.tr(
                  namedArgs: {'name': forPersonName ?? ''},
                ),
                style: AppTextStyles.font12Bold.copyWith(
                  color: AppColors.blue200,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
