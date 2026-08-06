import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/spacing.dart';

/// Skeleton placeholder shown while cities load — communicates "content is
/// coming here" instead of a bare spinner floating in empty space.
class CityPickerLoadingList extends StatelessWidget {
  const CityPickerLoadingList({super.key, required this.horizontalPadding});

  final double horizontalPadding;

  @override
  Widget build(final BuildContext context) {
    final colors = context.customColors;
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding)
          .copyWith(top: rh(4)),
      itemCount: 6,
      itemBuilder: (final BuildContext context, final int i) => Container(
        height: rh(72),
        margin: EdgeInsets.only(bottom: rh(10)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
      )
          .animate(
              onPlay: (final AnimationController c) => c.repeat(reverse: true))
          .fadeIn(duration: 700.ms, delay: (i * 60).ms)
          .then()
          .custom(
            duration: 700.ms,
            builder: (final BuildContext context, final double value,
                    final Widget child) =>
                Opacity(opacity: 0.55 + (0.45 * value), child: child),
          ),
    );
  }
}
