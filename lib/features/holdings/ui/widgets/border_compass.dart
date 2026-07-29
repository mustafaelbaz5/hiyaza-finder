import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/extensions/context_ext.dart';

/// A 3×3 "compass" — the holding ID sits in the center, its four borders
/// (north/south/east/west) surround it. A border becomes tappable when the
/// caller resolves it to a neighboring holding ID via [resolveBorder].
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
    required this.resolveBorder,
    required this.onNavigate,
    required this.onUnresolved,
  });

  final String holdingId;
  final String? north;
  final String? south;
  final String? east;
  final String? west;

  /// Returns the neighboring holding ID for a border's text, or `null` if
  /// it isn't a confident match (not navigable).
  final String? Function(String borderText) resolveBorder;
  final void Function(String holdingId) onNavigate;

  /// Called when a border has non-empty text but no confident match was
  /// found — the cell is still tappable, but there's nowhere to navigate.
  final void Function(String borderText) onUnresolved;

  @override
  Widget build(final BuildContext context) {
    return Column(
      children: [
        _BorderCell(label: 'شمال (البحري)', text: north, resolved: _resolve(north), onTapUnresolved: onUnresolved),
        const SizedBox(height: 8),
        Row(
          textDirection: TextDirection.ltr,
          children: [
            Expanded(
              child: _BorderCell(
                label: 'غرب (الغربي)',
                text: west,
                resolved: _resolve(west),
                onTapUnresolved: onUnresolved,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CenterCell(holdingId: holdingId),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BorderCell(
                label: 'شرق (الشرقي)',
                text: east,
                resolved: _resolve(east),
                onTapUnresolved: onUnresolved,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _BorderCell(label: 'جنوب (القبلي)', text: south, resolved: _resolve(south), onTapUnresolved: onUnresolved),
      ],
    );
  }

  ({String holdingId, VoidCallback onTap})? _resolve(final String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final String? neighborId = resolveBorder(text);
    if (neighborId == null || neighborId == holdingId) return null;
    return (holdingId: neighborId, onTap: () => onNavigate(neighborId));
  }
}

class _CenterCell extends StatelessWidget {
  const _CenterCell({required this.holdingId});

  final String holdingId;

  @override
  Widget build(final BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.primary200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.crop_square_rounded,
                color: AppColors.white,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                '#$holdingId',
                style: AppTextStyles.font14Bold.copyWith(
                  color: AppColors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(
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
    required this.resolved,
    required this.onTapUnresolved,
  });

  final String label;
  final String? text;
  final ({String holdingId, VoidCallback onTap})? resolved;
  final void Function(String borderText) onTapUnresolved;

  bool get _isNavigable => resolved != null;

  bool get _hasUnresolvedText =>
      resolved == null && text != null && text!.trim().isNotEmpty;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    final String displayText = (text == null || text!.trim().isEmpty)
        ? '—'
        : text!;

    return InkWell(
      onTap: resolved?.onTap ??
          (_hasUnresolvedText ? () => onTapUnresolved(text!) : null),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: _isNavigable ? colors.infoBackground : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isNavigable ? colors.info : colors.border,
            width: _isNavigable ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.font12Regular.copyWith(color: colors.textHint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isNavigable) ...[
                  Icon(Icons.touch_app_rounded, size: 14, color: colors.info),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    displayText,
                    style: AppTextStyles.font14SemiBold.copyWith(
                      color: _isNavigable ? colors.info : colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
