import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';

/// `null` in the sentinel below means "All"; the outer `Future` itself is
/// `null` only when the sheet is dismissed without a selection, in which
/// case the caller should leave the current focus unchanged.
const Object _allBasin = Object();

/// Shows a bottom sheet letting the user narrow search to one اسم الحوض
/// value, defaulting to "All". Returns the chosen basin (`null` = All), or
/// nothing if dismissed without a choice. [holdingCounts] (holdingId count
/// per basin) is shown beside each basin so the user can see its size.
Future<String?> showBasinFilterSheet(
  final BuildContext context, {
  required final List<String> basins,
  required final String? selected,
  final Map<String, int> holdingCounts = const <String, int>{},
}) async {
  final Object? result = await showModalBottomSheet<Object?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (final BuildContext context) => _BasinFilterSheet(
      basins: basins,
      selected: selected,
      holdingCounts: holdingCounts,
    ),
  );
  if (result == null) return selected; // dismissed — keep current focus
  return identical(result, _allBasin) ? null : result as String;
}

class _BasinFilterSheet extends StatelessWidget {
  const _BasinFilterSheet({
    required this.basins,
    required this.selected,
    required this.holdingCounts,
  });

  final List<String> basins;
  final String? selected;
  final Map<String, int> holdingCounts;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return SafeArea(
      child: Container(
        margin: EdgeInsets.only(top: rh(60)),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'holdings.basin.title'.tr(),
                    style: AppTextStyles.font18Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  verticalSpacing(6),
                  Text(
                    'holdings.basin.subtitle'.tr(),
                    style: AppTextStyles.font14Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            verticalSpacing(12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(
                  horizontal: rw(16),
                ).copyWith(bottom: rh(24)),
                children: [
                  _BasinTile(
                    label: 'holdings.basin.all'.tr(),
                    count: holdingCounts.values.fold<int>(
                      0,
                      (final int a, final int b) => a + b,
                    ),
                    isSelected: selected == null,
                    onTap: () => Navigator.pop(context, _allBasin),
                  ),
                  for (final (int i, String basin) in basins.indexed)
                    _BasinTile(
                      label: basin,
                      count: holdingCounts[basin],
                      isSelected: selected == basin,
                      onTap: () => Navigator.pop(context, basin),
                    ).animate(delay: (i * 25).ms).fadeIn(duration: 180.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BasinTile extends StatelessWidget {
  const _BasinTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Holding count shown as a trailing badge, or omitted when unknown.
  final int? count;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary50.withValues(alpha: 0.3)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary200 : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primary200 : colors.iconSecondary,
            ),
            horizontalSpacing(12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.font16SemiBold.copyWith(
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            if (count != null) ...[
              horizontalSpacing(8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary200.withValues(alpha: 0.15)
                      : colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.font12Bold.copyWith(
                    color: isSelected
                        ? AppColors.primary200
                        : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
