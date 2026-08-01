import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// A 3×3 "compass" — the holding ID sits in the center, its four borders
/// (north/south/east/west) surround it. Each border cell is tappable via
/// [onTapBorder] — the border text is free-form (APP_PLAN.md § 4), so
/// whether a tap resolves to another holding's data (vs. a "no data for
/// this person" snackbar) is decided by the caller, not this widget.
///
/// [isBorderNavigable] lets the caller mark, per cell, whether its text
/// resolves to another loaded holding — those cells get a highlighted
/// tinted/bordered style and a small link icon so it's visually obvious
/// *before* tapping which names are actually navigable, instead of every
/// cell looking equally (non-)interactive.
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
    this.onTapBorder,
    this.isBorderNavigable,
  });

  final String holdingId;
  final String? north;
  final String? south;
  final String? east;
  final String? west;

  /// Called with the tapped cell's raw border text (شمال/جنوب/شرق/غرب).
  final void Function(String? borderText)? onTapBorder;

  /// Whether [borderText] resolves to a holding the user can jump to —
  /// drives the highlighted styling. `null` (not provided) falls back to
  /// the plain, non-highlighted look for every cell.
  final bool Function(String? borderText)? isBorderNavigable;

  @override
  Widget build(final BuildContext context) {
    bool navigable(final String? text) => isBorderNavigable?.call(text) ?? false;

    return Column(
      children: [
        _BorderCell(
          label: 'شمال (البحري)',
          text: north,
          isNavigable: navigable(north),
          onTap: onTapBorder == null ? null : () => onTapBorder!(north),
        ),
        const SizedBox(height: 5),
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Expanded(
              child: _BorderCell(
                label: 'غرب (الغربي)',
                text: west,
                isNavigable: navigable(west),
                onTap: onTapBorder == null ? null : () => onTapBorder!(west),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(child: _CenterCell(holdingId: holdingId)),
            const SizedBox(width: 5),
            Expanded(
              child: _BorderCell(
                label: 'شرق (الشرقي)',
                text: east,
                isNavigable: navigable(east),
                onTap: onTapBorder == null ? null : () => onTapBorder!(east),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _BorderCell(
          label: 'جنوب (القبلي)',
          text: south,
          isNavigable: navigable(south),
          onTap: onTapBorder == null ? null : () => onTapBorder!(south),
        ),
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
  const _BorderCell({
    required this.label,
    required this.text,
    this.onTap,
    this.isNavigable = false,
  });

  final String label;
  final String? text;
  final VoidCallback? onTap;

  /// Highlights this cell (tinted background, primary-colored border, small
  /// link icon) so a navigable name is visually distinct from plain
  /// boundary text before the user taps it.
  final bool isNavigable;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String displayText = (text == null || text!.trim().isEmpty) ? '—' : text!;

    return InkWell(
      onTap: isNavigable ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: isNavigable ? AppColors.primary50.withValues(alpha: 0.25) : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isNavigable ? AppColors.primary200 : colors.border,
            width: isNavigable ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
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
                if (isNavigable) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.touch_app_rounded,
                    size: 11,
                    color: AppColors.primary200,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 1),
            Text(
              displayText,
              style: AppTextStyles.font14SemiBold.copyWith(
                color: isNavigable ? AppColors.primary300 : colors.textPrimary,
                fontSize: 12,
                decoration: isNavigable ? TextDecoration.underline : TextDecoration.none,
                decorationColor: AppColors.primary200,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
