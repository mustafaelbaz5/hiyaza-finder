import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// Opens a compact, RTL-safe selector for values users change frequently.
///
/// It intentionally returns only the selected value. Validation, note
/// synchronization, persistence, and success feedback stay with the calling
/// Cubit/screen rather than leaking business rules into this UI component.
Future<String?> showParcelQuickChoiceSheet(
  final BuildContext context, {
  required final String title,
  required final String? selected,
  required final List<String> options,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (final BuildContext sheetContext) => _ParcelQuickChoiceSheet(
        title: title,
        selected: selected,
        options: options,
      ),
    );

class _ParcelQuickChoiceSheet extends StatelessWidget {
  const _ParcelQuickChoiceSheet({
    required this.title,
    required this.selected,
    required this.options,
  });

  final String title;
  final String? selected;
  final List<String> options;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final MediaQueryData media = MediaQuery.of(context);
    final double maxHeight = media.size.height * 0.62;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.right,
                style: AppTextStyles.font18Bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                selected == null || selected!.trim().isEmpty ? '-' : selected!,
                textAlign: TextAlign.right,
                style: AppTextStyles.font14SemiBold.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (final BuildContext _, final int __) =>
                      const SizedBox(height: 6),
                  itemBuilder: (final BuildContext context, final int index) {
                    final String option = options[index];
                    final bool isSelected = option == selected;
                    return Material(
                      color: isSelected
                          ? AppColors.green200.withValues(alpha: 0.12)
                          : colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pop(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  option,
                                  textAlign: TextAlign.right,
                                  style: AppTextStyles.font14SemiBold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.green200,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
