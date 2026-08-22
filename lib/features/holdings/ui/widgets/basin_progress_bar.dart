import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// A thin, rounded progress bar — green once fully complete, primary color
/// otherwise. Shared by [BasinCard] (per-basin) and the home screen's
/// footer (whole-city total).
class BasinProgressBar extends StatelessWidget {
  const BasinProgressBar({
    super.key,
    required this.progress,
    this.isFullyCompleted = false,
    this.height = 8,
  });

  /// 0.0–1.0.
  final double progress;
  final bool isFullyCompleted;
  final double height;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: progress.clamp(0, 1),
        minHeight: height,
        backgroundColor: colors.surfaceVariant,
        color: isFullyCompleted ? AppColors.green200 : AppColors.primary200,
      ),
    );
  }
}
