import 'package:flutter/material.dart';

/// Lays [children] out as a wrap that adapts to the available width: one
/// column on phones, two on tablets, three on laptop/desktop — keeps a
/// card with many fields short instead of one long scrolling list.
class ResponsiveFieldsWrap extends StatelessWidget {
  const ResponsiveFieldsWrap({super.key, required this.children});

  final List<Widget> children;

  static const double _spacing = 8;

  @override
  Widget build(final BuildContext context) {
    return LayoutBuilder(
      builder: (final BuildContext context, final BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 900 ? 3 : (width >= 520 ? 2 : 1);
        final double itemWidth =
            columns == 1 ? width : (width - _spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final Widget child in children) SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
