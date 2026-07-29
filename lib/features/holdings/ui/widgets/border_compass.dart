import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// A 3×3 "compass" — the holding ID sits in the center, its four borders
/// (north/south/east/west) surround it as plain, non-navigable text.
///
/// The middle row is forced to LTR so west/east always render on the
/// geographically correct side regardless of the app's RTL layout.
class BorderCompass extends StatelessWidget {
  const BorderCompass({
    super.key,
    required this.holdingId,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final String holdingId;
  final String? north;
  final String? south;
  final String? east;
  final String? west;

  @override
  Widget build(final BuildContext context) {
    return Column(
      children: [
        _BorderCell(label: 'شمال (البحري)', text: north),
        const SizedBox(height: 5),
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Expanded(child: _BorderCell(label: 'غرب (الغربي)', text: west)),
            const SizedBox(width: 5),
            Expanded(child: _CenterCell(holdingId: holdingId)),
            const SizedBox(width: 5),
            Expanded(child: _BorderCell(label: 'شرق (الشرقي)', text: east)),
          ],
        ),
        const SizedBox(height: 5),
        _BorderCell(label: 'جنوب (القبلي)', text: south),
      ],
    );
  }
}

class _CenterCell extends StatelessWidget {
  const _CenterCell({required this.holdingId});

  final String holdingId;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primary200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.crop_square_rounded,
            color: AppColors.white,
            size: 15,
          ),
          const SizedBox(height: 2),
          Text(
            '#$holdingId',
            style: AppTextStyles.font12Bold.copyWith(
              color: AppColors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
          duration: 350.ms,
        );
  }
}

class _BorderCell extends StatelessWidget {
  const _BorderCell({required this.label, required this.text});

  final String label;
  final String? text;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String displayText =
        (text == null || text!.trim().isEmpty) ? '—' : text!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.font12Regular.copyWith(
              color: colors.textHint,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            displayText,
            style: AppTextStyles.font14SemiBold.copyWith(
              color: colors.textPrimary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
